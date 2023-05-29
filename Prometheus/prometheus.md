# K8s Cluster Monitoring with Prometheus
We are going to show how to install Prometheus and Grafana using Helm charts. We are also going to learn how we can connect Prometheus and Grafana together and set up a basic dashboard on Grafana to monitor resources on the Kubernetes cluster.

Prometheus takes care of data fetching as a data source and feeds that data into Grafana which is used to visualize data with attractive dashboards.

# Create a directory for `YAML` files
Create a directory for all the `yaml` files needed for the installation of Prometheus:
```sh
cd ~
mkdir -p K8s/Prometheus
cd K8s/Prometheus
```

# Create a namespace
We start by creating a new namespace for our Prometheus deployment with the command:
```sh
cat <<EOF | tee prometheus-ns.yaml > /dev/null
apiVersion: v1
kind: Namespace
metadata:
  name: prometheus
EOF
```

Create the namespace:
```sh
kubectl create -f prometheus-ns.yaml
```

Check that it as indeed been created with the command:
```sh
kubectl get ns
```

# Create NFS directory
We need at least two Peristent Volume for Prometheus. I'll be using an NFS server on the master node. The directories need to exist on the NSF drive before we configure the PV and PVC.

Create the directories on the NFS server and change the owner:
```sh
mkdir /nfs-data/prom-srv-pv
mkdir /nfs-data/prom-ale-pv
sudo chown -R nobody:nogroup /nfs-data/prom-srv-pv
sudo chown -R nobody:nogroup /nfs-data/prom-ale-pv
```

# PV and PVC for Prometheus Server
Prometheus needs storage space to store data. There's 2 components that needs storage. The server and the alert manager. Let's create 2 PV's to an NFS volume on the master node.

Create a Persistent Volume (PV) and a Persistent Volume Claim (PVC) `yaml` file called `prom-srv-pv-pvc.yaml` with the following content. This is for the server component:

```sh
cat <<EOF | tee prom-srv-pv-pvc.yaml > /dev/null
apiVersion: v1
kind: PersistentVolume
metadata: 
  name: prometheus-srv-pv
  namespace: prometheus
  labels:
    type: nfs
    app: prometheus-server
spec:
  storageClassName: prometheus-srv-pv
  accessModes: 
    - ReadWriteMany
  capacity: 
    storage: 1Gi
  nfs: 
    path: "/nfs-data/prom-srv-pv"
    server: k8smaster1.isociel.com
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-srv-pvc
  namespace: prometheus
  labels:
    type: nfs
    app: prometheus-srv-pvc
spec:
  storageClassName: prometheus-srv-pv
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  volumeName: prometheus-srv-pv
status:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
EOF
```

Create the PV and PVC, for the server portion, to your cluster by running the command:
```sh
kubectl create -f prom-srv-pv-pvc.yaml
```

Output should be:
```
persistentvolume/prometheus-srv-pv created
persistentvolumeclaim/prometheus-srv-pvc created
```

## PV for for Prometheus Alert
Create a Persistent Volume (PV) and a Persistent Volume Claim (PVC) `yaml` file called `prom-ale-pv-pvc.yaml` with the following content. This is for the alert component:
```sh
cat <<EOF | tee prom-ale-pv-pvc.yaml > /dev/null
apiVersion: v1
kind: PersistentVolume
metadata: 
  name: prometheus-ale-pv
  namespace: prometheus
  labels:
    type: nfs
    app: prometheus-server
spec:
  storageClassName: prometheus-ale-pv
  accessModes: 
    - ReadWriteOnce
  capacity: 
    storage: 1Gi
  nfs: 
    path: "/nfs-data/prom-ale-pv"
    server: k8smaster1.isociel.com
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  # Can't be customized :-(
  name: storage-prometheus-alertmanager-0
  namespace: prometheus
  labels:
    type: nfs
    app: prometheus-alertmanager
spec:
  storageClassName: prometheus-ale-pv
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: prometheus-ale-pv
status:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
EOF
```

Create the PV and PVC, for the alert portion, to your cluster by running the command:
```sh
kubectl create -f prom-ale-pv-pvc.yaml
```

Output should be:
```
persistentvolume/prometheus-ale-pv created
persistentvolumeclaim/storage-prometheus-alertmanager-0 created
```

## Test Persistent Volumes
Make sure that both PV's have been created and that both PVC's are bound to the respective PV's:
```sh
kubectl get pv,pvc -n prometheus
```

    NAME                                 CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                               STORAGECLASS        REASON   AGE
    persistentvolume/prometheus-ale-pv   1Gi        RWX            Retain           Bound    prometheus/storage-prometheus-alertmanager-0   prometheus-ale-pv            108s
    persistentvolume/prometheus-srv-pv   1Gi        RWX            Retain           Bound    prometheus/prometheus-srv-pvc                  prometheus-srv-pv            25m

    NAME                                                      STATUS   VOLUME              CAPACITY   ACCESS MODES   STORAGECLASS        AGE
    persistentvolumeclaim/prometheus-srv-pvc                  Bound    prometheus-srv-pv   1Gi        RWX            prometheus-srv-pv   25m
    persistentvolumeclaim/storage-prometheus-alertmanager-0   Bound    prometheus-ale-pv   1Gi        RWX            prometheus-ale-pv   108s

# Install Prometheus
I'll use `helm` to install Prometheus.

Get Repository Info:
```sh
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

Check the version available on Helm (Optional):
```sh
helm show chart prometheus-community/prometheus | grep ^appVersion
```

Time to install Prometheus with Helm. We'll use a `yaml` file for the configuration adjustments. Let's create the file and start the installation with `helm`.

>**Note:** The `alertmanager` section is not taken into account in the installation. The server section is applied correctly.

Create the file `values.yaml`:
```sh
cat <<EOF | tee values.yaml > /dev/null
# https://github.com/helm/charts/blob/master/stable/prometheus/values.yaml
# The section 'alertmanager' is not read or there's a bug
# helm show values prometheus-community/alertmanager
alertmanager:
  persistence:
    ## If true, alertmanager will create/use a Persistent Volume Claim
    ## If false, use emptyDir
    ##
    enabled: true
    ## Requires alertmanager.persistentVolume.enabled: true
    ## If defined, PVC must be created manually before volume will be bound
    existingClaim: "prometheus-ale-pvc"
    ## alertmanager data Persistent Volume Storage Class
    ## If defined, storageClassName: <storageClass>
    ## If set to "-", storageClassName: "", which disables dynamic provisioning
    ## If undefined (the default) or set to null, no storageClassName spec is
    ##   set, choosing the default provisioner.  (gp2 on AWS, standard on
    ##   GKE, AWS & OpenStack)
    ##
    storageClass: "prometheus-ale-pv"

server:
  persistentVolume:
    ## If true, Prometheus server will create/use a Persistent Volume Claim
    ## If false, use emptyDir
    ##
    enabled: true
    ## Prometheus server data Persistent Volume existing claim name
    ## Requires server.persistentVolume.enabled: true
    ## If defined, PVC must be created manually before volume will be bound
    existingClaim: "prometheus-srv-pvc"
EOF
```

Install Prometheus in namespace `prometheus` with a customized configuration:
```sh
helm install prometheus prometheus-community/prometheus -n prometheus -f values.yaml
```

>See this link for the [Configuration](https://github.com/helm/charts/blob/master/stable/prometheus/README.md) of `values.yaml`

The lengthy output should looke like this:

>**Note:** The labels `app=prometheus,component=server` are wrong. They shoud be `app.kubernetes.io/name=prometheus,app.kubernetes.io/component=server`. If yhou type the command `kubectl get pods` you'll get an error. Replace the labels and it should work correctly.

    NAME: prometheus
    LAST DEPLOYED: Sun May 28 12:35:36 2023
    NAMESPACE: prometheus
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None
    NOTES:
    The Prometheus server can be accessed via port 80 on the following DNS name from within your cluster:
    prometheus-server.prometheus.svc.cluster.local


    Get the Prometheus server URL by running these commands in the same shell:
    export POD_NAME=$(kubectl get pods --namespace prometheus -l "app=prometheus,component=server" -o jsonpath="{.items[0].metadata.name}")

    The Prometheus alertmanager can be accessed via port  on the following DNS name from within your cluster:
    prometheus-%!s(<nil>).prometheus.svc.cluster.local


    Get the Alertmanager URL by running these commands in the same shell:
    export POD_NAME=$(kubectl get pods --namespace prometheus -l "app=prometheus,component=" -o jsonpath="{.items[0].metadata.name}")
    kubectl --namespace prometheus port-forward $POD_NAME 9093
    #################################################################################
    ######   WARNING: Pod Security Policy has been disabled by default since    #####
    ######            it deprecated after k8s 1.25+. use                        #####
    ######            (index .Values "prometheus-node-exporter" "rbac"          #####
    ###### .          "pspEnabled") with (index .Values                         #####
    ######            "prometheus-node-exporter" "rbac" "pspAnnotations")       #####
    ######            in case you still need it.                                #####
    #################################################################################


    The Prometheus PushGateway can be accessed via port 9091 on the following DNS name from within your cluster:
    prometheus-prometheus-pushgateway.prometheus.svc.cluster.local


    Get the PushGateway URL by running these commands in the same shell:
    export POD_NAME=$(kubectl get pods --namespace prometheus -l "app=prometheus-pushgateway,component=pushgateway" -o jsonpath="{.items[0].metadata.name}")
    kubectl --namespace prometheus port-forward $POD_NAME 9091

    For more information on running Prometheus, visit:
    https://prometheus.io/

Check that all Prometheus Pods are `running`. None should be in `pending` status:
```sh
kubectl get pods -n prometheus
```

Make sure the pods `prometheus-server-xxxxx` and `prometheus-alertmanager-0` are in status `Running`. The most common problem is the persistent volume claim (PVC).

Output should look like this:

    NAME                                                 READY   STATUS    RESTARTS   AGE
    prometheus-alertmanager-0                            1/1     Running   0          2m30s
    prometheus-kube-state-metrics-64b4cd6658-847fb       1/1     Running   0          2m30s
    prometheus-prometheus-node-exporter-4gwzk            1/1     Running   0          2m30s
    prometheus-prometheus-node-exporter-d52cn            1/1     Running   0          2m30s
    prometheus-prometheus-node-exporter-ffs2k            1/1     Running   0          2m30s
    prometheus-prometheus-node-exporter-vtnbk            1/1     Running   0          2m30s
    prometheus-prometheus-pushgateway-7cfd5f66f4-7s4rv   1/1     Running   0          2m30s
    prometheus-server-76b45bbf6b-btkff                   2/2     Running   0          2m30s

# Troubleshooting commands
Use the command to troubleshoot the `prometheus-server` Pods:
```sh
kubectl describe pods prometheus-server-76b45bbf6b-btkff -n prometheus
```

Use the command to troubleshoot the `prometheus-alertmanager` Pods:
```sh
kubectl describe pods prometheus-alertmanager-0 -n prometheus
```

Use this command to list the values for `alertmanager`:
```sh
helm show values prometheus-community/alertmanager
```

# Create Cluster Role, Service Account
https://phoenixnap.com/kb/prometheus-kubernetes

# Create Prometheus Service
Prometheus is currently running in the cluster but you can't access it externally. The procedure will create a K8s service to get access to the data Prometheus has collected:

```sh
cat <<EOF | tee prometheus-nodeport.yaml > /dev/null
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: prometheus
spec:
  type: NodePort
  ports:
  - name: web
    nodePort: 30900     # port assigned on each node for external access
    port: 9090          # port exposed internally in the cluster
    protocol: TCP
  selector:
    app.kubernetes.io/name: prometheus
    app.kubernetes.io/component: server
EOF
```

Create the service with the command:
```sh
kubectl create -f prometheus-nodeport.yaml
```

After creating a Service with the above manifest, the web UI of Prometheus will be accessible by browsing to any of the master and worker nodes using:
```sh
http://<node-ip>:30900/
```

# Cleanup Prometheus (just in case 😀)
If you ever want to uninstall Prometheus completely, use the commands below (deleting the namespace should be sufficient):
```sh
helm delete prometheus --namespace prometheus
kubectl delete -f prom-srv-pv-pvc.yaml
kubectl delete -f prom-ale-pv-pvc.yaml
kubectl delete -f prometheus-nodeport.yaml
kubectl delete -f prom-namespace.yaml
```

You shouldn't see anything in the namespace `prometheus`
```sh
kubectl get all -n prometheus
```

If you want to remove the images, go on each node (master and worker):
1. List the image(s)

List the local images:
```sh
crictl images ls
```

The ouput should look like this:
```
IMAGE                                                    TAG                 IMAGE ID            SIZE
...
quay.io/prometheus-operator/prometheus-config-reloader   v0.65.1             27473df42d72c       5.2MB
quay.io/prometheus/alertmanager                          v0.25.0             c8568f914cd25       30.8MB
quay.io/prometheus/node-exporter                         v1.5.0              0da6a335fe135       11.5MB
quay.io/prometheus/prometheus                            v2.44.0             75972a31ad256       93MB
...
```


2. Delete the image(s) with the command:
```sh
crictl rmi <IMAGE ID>
```
