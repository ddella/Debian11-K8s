# Install Grafana

## Create namaspace
Create a namespace named `grafana` by running the following command.
```sh
kubectl create namespace grafana
```

If you want to use a `yaml` file to create the namespace, you can use this one called `namespace.yaml`:
```sh
cat <<EOF | tee namespace.yaml > /dev/null
apiVersion: v1
kind: Namespace
metadata:
  name: grafana
EOF
```

Create the namespace:
```sh
kubectl create -f namespace.yaml
```

Check that it as indeed been created with the command:
```sh
kubectl get ns
```

## Create NFS directory
Create the directory on the NFS server and change the owner of it:
```sh
mkdir /nfs-data/grafana-pv
sudo chown -R nobody:nogroup /nfs-data/grafana-pv
```

Create a Persistent Volume (PV) and a Persistent Volume Claim (PVC) `yaml` file called `grafana-pv-pvc.yaml` with the following content. This is for the server component:

>**Note:** The directory needs to exist on the NSF drive

## Create PV and PVC
```sh
cat <<EOF | tee grafana-pv.yaml > /dev/null
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pvc-prom-grafana-0
  namespace: grafana
  labels:
    type: nfs
    app: grafana
spec:
  storageClassName: grafana
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
  nfs: 
    path: "/nfs-data/grafana-pv"
    server: k8smaster1.isociel.com
EOF
```

```sh
cat <<EOF | tee grafana-pvc.yaml > /dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prom-grafana
  namespace: grafana
  labels:
    type: nfs
    app: grafana
spec:
  storageClassName: grafana
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  volumeName: pvc-prom-grafana-0
status:
  accessModes:
    - ReadWriteOnce
  capacity:
    storage: 1Gi
EOF
```

Create the PV and PVC to your cluster by running the command:
```sh
kubectl apply -f grafana-pv.yaml
kubectl apply -f grafana-pvc.yaml
```

Output should be:

    persistentvolume/grafana-pv created
    persistentvolumeclaim/grafana-pvc created

Verify that the PVC is bound to the STORAGECLASS `grafana-pv`:
```sh
kubectl get pvc -n grafana
```

## Install Grafana
This command installs Grafana and overrides a few default values for the integration with Prometheus.

```sh
helm install grafana grafana/grafana -n grafana \
--set persistence.enabled=true \
--set persistence.existingClaim=prom-grafana \
--set adminPassword=AdminGrafana \
--set datasources.datasources.yaml.apiVersion=1 \
--set datasources.datasources.yaml.datasources[0].name=Prometheus \
--set datasources.datasources.yaml.datasources[0].type=prometheus \
--set datasources.datasources.yaml.datasources[0].url=http://prometheus-server.kube-monitoring.svc.cluster.local \
--set datasources.datasources.yaml.datasources[0].access=proxy \
--set datasources.datasources.yaml.datasources[0].isDefault=true
```

- Adjust the value `datasources[0].url` which is the url of `prometheus`
- `adminPassword` is the password we want to use to login to the Grafana dashboard

The output shoud look like this:

  NAME: grafana
  LAST DEPLOYED: Sun May 28 19:57:21 2023
  NAMESPACE: grafana
  STATUS: deployed
  REVISION: 1
  NOTES:
  1. Get your 'admin' user password by running:

    kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo


  2. The Grafana server can be accessed via port 80 on the following DNS name from within your cluster:

    grafana.grafana.svc.cluster.local

    Get the Grafana URL to visit by running these commands in the same shell:
      export POD_NAME=$(kubectl get pods --namespace grafana -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
      kubectl --namespace grafana port-forward $POD_NAME 3000

  3. Login with the password from step 1 and the username: admin

Once you run the above command, verify that the Grafana Pod is in status `Running` with the command:
```sh
kubectl get pods -n grafana
```

The output should look like that:

  NAME                       READY   STATUS    RESTARTS   AGE
  grafana-584dbbb97f-5f7kg   1/1     Running   0          28s

you can run the following command to verify all the resources in `grafana`:
```sh
kubectl get all -n grafana
```

## Log into the UI
Get your user `admin` password by running the command:
```sh
kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Log into Grafana with the user `admin` and the password that you got above.

# Create Grafana Service
Grafana is currently running in the cluster but you can't access it externally. The procedure will create a K8s service to get access to Grafana:

```sh
cat <<EOF | tee grafana-nodeport.yaml > /dev/null
apiVersion: v1
kind: Service
metadata:
  name: grafana-nodeport
  namespace: grafana
spec:
  type: NodePort
  ports:
  - name: web
    nodePort: 30300     # port assigned on each node for external access
    port: 3000          # port exposed internally in the cluster
    protocol: TCP
  selector:
    app.kubernetes.io/name: grafana
EOF
```

Create the service with the command:
```sh
kubectl create -f grafana-nodeport.yaml
```

After creating a Service with the above manifest, the web UI of Prometheus will be accessible by browsing to any of the master and worker nodes using:
```sh
http://<node-ip>:30300/
```

## Service
```yaml
apiVersion: v1
kind: Service
metadata:
  name: grafana
spec:
  ports:
    - port: 3000
      protocol: TCP
      targetPort: http-grafana
  selector:
    app: grafana
  sessionAffinity: None
  type: LoadBalancer
```

```sh
kubectl apply -f grafana-svc.yaml
```

Grafana should be accessible via http://<node ip>:3000, using admin as both the username and password.

## Cleanup Grafana (just in case 😀)
If you ever want to uninstall Grafana completely, use the commands below (deleting the namespace should be sufficient):
```sh
helm delete grafana --namespace grafana
kubectl delete -f grafana-pvc.yaml
kubectl delete -f grafana-pv.yaml
kubectl delete -f grafana-nodeport.yaml
kubectl delete -f namespace.yaml
```

You shouldn't see anything in the namespace `grafana`
```sh
kubectl get all -n grafana
```

## Reference
https://techblogs.42gears.com/deploying-prometheus-and-grafana-using-helm-in-kubernetes/
https://grafana.com/docs/grafana/latest/setup-grafana/installation/kubernetes/

https://phoenixnap.com/kb/prometheus-kubernetes
https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/user-guides/exposing-prometheus-and-alertmanager.md
https://github.com/prometheus-operator/prometheus-operator/tree/main
https://artifacthub.io/


https://grafana.com/
https://prometheus.io/

http://k8smaster1/api/v1/proxy/namespaces/kube-monitoring/services/prometheus-service:9090/
