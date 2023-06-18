# Jenkins
Jenkins is a self-contained, open source automation server which can be used to automate all sorts of tasks related to building, testing, and delivering or deploying software. It is written in Java for continuous integration. Jenkins is used to build and test your software projects continuously making it easier for developers to integrate changes to the project, and making it easier for users to obtain a fresh build.

## Setup Jenkins On Kubernetes
This demonstrates how to install Jenkins running in a Pod on a Kubernetes Cluster using manifest files. This is a seven steps process.

1. Create a Namespace
2. Create a service account with Kubernetes admin permissions.
3. Create an NFS persistent volume for persistent Jenkins data on Pod restarts.
4. Create an NFS persistent volume claim
5. Create a deployment with a `YAML` file.
6. Test Pods
7. Create a service YAML and deploy it.

### 1.  Create a Namespace for Jenkins with the file `namespace.yaml`
```sh
kubectl create -f namespacespace.yaml
```

### 2. Apply the manifest `serviceAccount.yaml` to th K8s cluster
See the file `serviceAccount.yaml`
```sh
kubectl create -f serviceAccount.yaml
```

### 3. Create a Persistent Volume
Kubernetes persistent volumes (PVs) are a unit of storage provided by an administrator as part of a Kubernetes cluster. Just as a node is a compute resource used by the cluster, a PV is a storage resource. Persistent volumes are independent of the lifecycle of the pod that uses it, meaning that even if the pod shuts down, the data in the volume is not erased. You will need an NFS server.
```sh
kubectl apply -f persistentVolume.yaml
```

### 4. Create a Persistent Volume Claim
To mount persistent volume inside a pod, we have to specify its persistent volume claim. So let's create persistent volume claim using the `persistentVolumeClaim.yaml` file:
```sh
kubectl apply -f persistentVolumeClaim.yaml
```

Check that everything is as expected it those two commands:
```sh
kubectl get pvc -n jenkins-ns jenkins-pvc
kubectl get pv -n jenkins-ns jenkins-pv
```

You should see output that looks like this:
```
$ kubectl get pvc -n jenkins-ns jenkins-pvc
NAME          STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS   AGE
jenkins-pvc   Bound    jenkins-pv   2Gi        RWX            jenkins-pv     25d

$ kubectl get pv -n jenkins-ns jenkins-pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                    STORAGECLASS   REASON   AGE
jenkins-pv   2Gi        RWX            Retain           Bound    jenkins-ns/jenkins-pvc   jenkins-pv              25d
```

### 5. Create the deployment
```sh
kubectl apply -f deployment.yaml
```

### 6. Tests
Verify that the container in the Pods are running:
```sh
kubectl get pods -n jenkins-ns -o=wide
```

The output should look like this:
```
NAME                       READY   STATUS    RESTARTS   AGE   IP          NODE          NOMINATED NODE   READINESS GATES
jenkins-6d88f67656-fdr62   1/1     Running   0          21m   10.0.2.81   s700sml4151   <none>           <none>
```

With the name of the Pods, check it's status and look at the logs for any kind of errors:
```sh
kubectl describe pod jenkins-6d88f67656-fdr62 -n jenkins-ns
```

Get the deployment status:
```sh
kubectl get deployments -n jenkins-ns -o=wide
```

The output should look like this, execpt for the image name. I customized it:
```
NAME      READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES              SELECTOR
jenkins   1/1     1            1           2d17h   jenkins      jenkins:2.410-py3   app=jenkins-server
```


You can get the deployment details using the following command:
```sh
kubectl describe deployments jenkins -n jenkins-ns
```

### 7. Accessing Jenkins Using Kubernetes NodePort Service
We have now created a deployment. However, it is not accessible to the outside world. For accessing the Jenkins deployment from the outside world, we need to create a service and map it to the deployment.

Use the following file `service.yaml` to create a K8s NodePort service:
```sh
kubectl create -f service.yaml
```

Now, when browsing to any one of the Node IPs on port 32000, you will be able to access the Jenkins dashboard.
```sh
curl http://<node-ip>:32000
```

## Initial Password
Getting the initial password is the most complicated part of the installation.

Jump into a container:
```sh
 kubectl exec -it jenkins-6d88f67656-fdr62 -n jenkins-ns -- /bin/bash
```

The password is in the file `/var/jenkins_home/secrets/initialAdminPassword`:
```
jenkins@jenkins-6d88f67656-fdr62:/$ cat /var/jenkins_home/secrets/initialAdminPassword
9d2e3d1e4a3d4381a8e30d15a63f8fad
```

You could also go on the NFS server and read the file `secrets/initialAdminPassword` in the NFS mount:
```
ubuntu@daniel [ ~ ]$ cat /mnt/nfs_share/secrets/initialAdminPassword
9d2e3d1e4a3d4381a8e30d15a63f8fad
```

## Access Jenkins
From anywhere, you should be able to access Jenkins with the IP address of any **nodes**, not Pods, on port `TCP/32000`.

```
http://<Any node IP address>:32000
```

## Final tests
The `kubectl api-resources` enumerates the resource types available in the cluster. So we can use it by combining it with `kubectl get` to list every instance of every resource type in a Kubernetes namespace.

```sh
kubectl api-resources --verbs=list --namespaced -o name | xargs -n 1 kubectl get --show-kind --ignore-not-found -n jenkins-ns
```

```
NAME                         DATA   AGE
configmap/kube-root-ca.crt   1      25d
NAME                        ENDPOINTS             AGE
endpoints/jenkins-service   10.255.140.121:8080   25d
NAME                                STATUS   VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS   AGE
persistentvolumeclaim/jenkins-pvc   Bound    jenkins-pv   2Gi        RWX            jenkins-pv     25d
NAME                          READY   STATUS    RESTARTS        AGE
pod/jenkins-6d88f67656-fdr62   1/1     Running   1 (2d15h ago)   2d17h
NAME                           SECRETS   AGE
serviceaccount/default         0         25d
serviceaccount/jenkins-admin   0         25d
NAME                      TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
service/jenkins-service   NodePort   10.111.181.24   <none>        8080:32000/TCP   25d
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/jenkins   1/1     1            1           2d17h
NAME                                DESIRED   CURRENT   READY   AGE
replicaset.apps/jenkins-6d6d88ff9   1         1         1       2d17h
NAME                                                   ADDRESSTYPE   PORTS   ENDPOINTS        AGE
endpointslice.discovery.k8s.io/jenkins-service-b8kqz   IPv4          8080    10.255.140.121   25d
```

Using the `kubectl get all` command we can list down all the pods, services, statefulsets, etc. in a namespace but not all the resources are listed using this command like persistent volume claim and service account.

# Update the version of Jenkins
In this section we'll perform a rolling update using `kubectl` to upgrade the version of Jenkins. Similar to application Scaling, the Service will load-balance the traffic only to available Pods during the update. An available Pod is an instance that is available to the users of the application.

Rolling updates allow the following actions:

- Promote an application from one environment to another (via container image updates)
- Rollback to previous versions
- Continuous Integration and Continuous Delivery of applications with zero downtime

To update the image of Jenkins to version 2.410, use the set image subcommand, followed by the deployment name and the new image version:
```sh
kubectl set image deployments/jenkins jenkins=jenkins/jenkins:2.410 -n jenkins-ns
```

The output should look like this
```
deployment.apps/jenkins image updated
```

You can watch the Pods with the command:
```sh
watch -n 1 kubectl get pods -n jenkins-ns
```

>**Note:**Some of the output in the sections above have been taken after the upgrade. I'm sorry for the confusion but you should be able to figure it out 😉

## Rollout
Incase it doesn't work, you can rollout. Check the history and rollout to the version before the last:
```sh
kubectl rollout history deployment/jenkins  -n jenkins-ns
```

Output:
```
deployment.apps/jenkins
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
3         <none>
```

Rollout with this command:
```sh
kubectl rollout undo deployment/jenkins --to-revision=2 -n jenkins-ns
```

Output:
```
deployment.apps/jenkins rolled back
```

## Reference
[Jenkins.io](https://www.jenkins.io/doc/book/installing/kubernetes/#install-jenkins-with-yaml-files)
