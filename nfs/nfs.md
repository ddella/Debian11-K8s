<a name="readme-top"></a>

# NFS Server and Client configuration
## Definition of NFS
Network File System (NFS), is a distributed file system that allows various clients to access a shared directory on a server.

## Lab
For this tutorial we have 2 Debian 11 system on the same network. NFS uses a client/server model, we will use the following configuration:

| Type         | Hostname             | IP address    |
|--------------|----------------------|---------------|
| NFS server   | debian1.example.com  | 192.168.13.41 |
| NFS client   | debian2.example.com  | 192.168.13.42 |

## Update Client and Server
Make sure that client and server are up to date with the following commands:
```sh
sudo apt update
sudo apt -y upgrade
```

# Configuration of NFS Server on Debian 11 (**Server ONLY**)
Install NFS server:
```sh
sudo apt install nfs-kernel-server
```

Start the service:
```sh
sudo systemctl start nfs-kernel-server.service
sudo systemctl enable nfs-kernel-server.service
```

Create the mount point directory:
```sh
sudo mkdir /data
```

Change the permissions and ownership to match the following (Be sure that you know what you are doing):
```sh
sudo chown nobody:nogroup /data
# sudo chown -R nobody: /data/
sudo chmod -R 777 /data/
```

Create the file exports for NFS:
```sh
cat << EOF | sudo tee -a /etc/exports
/data 192.168.13.0/24(rw,no_subtree_check,no_root_squash)
EOF
```

Export it to the client(s):
```sh
sudo exportfs -arv
```

>**Note:** Remember to re-export your shares on the server with exportfs -arv if you made changes! The NFS server won’t pick them up automatically. Display your currently running exports with `exportfs -v`.  


Verify the NFS version (you can see this information in column two):
```sh
rpcinfo -p | grep nfs
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Configuration of NFS Client on Debian 11 (**Client ONLY**)
Install NFS client:
```sh
sudo apt install nfs-common
```

Create a mount point directory to map the NFS share:
```sh
mkdir ~/mnt/
```

Edit the file `/etc/fstab` and add the following line to mount NSF without root:
```sh
debian1.example.com:/data /home/daniel/mnt nfs rw,user,noauto
```

Mount the NFS drive (remove the `-vvvv` to be less verbose):
```sh
mount -vvvv debian1.example.com:/data ~/mnt/
```

# Time to test
Lets create a K8s deployment of 3 Nginx Pods and mount an NFS volume into `/usr/share/nginx/html` of each Pod to serve a simple web page. After mounting an NFS drive, create a file `index.html` to test the deployment.

## Create, test and delete an Nginx deployment
Create the deployment:
```sh
kubectl create -f nfs-web.yaml
```

Check the status of the deployment:
```sh
kubectl get pods -l role=web-frontend -o=wide
```

The results should look like this:

    NAME                        READY   STATUS    RESTARTS   AGE
    nfs-web-5ff688ccf8-7k22s    1/1     Running   0          6m59s
    nfs-web-5ff688ccf8-hlzz7    1/1     Running   0          6m59s
    nfs-web-5ff688ccf8-rrtmv    1/1     Running   0          6m59s

Get detailed information about the Deployment:
```sh
kubectl describe deployment nfs-web
```
  
Get detailed information about a Pod:
```sh
kubectl describe pod nfs-web-5ff688ccf8-7k22s
```
  
Jump inside the container of a Pod:
```sh
kubectl exec -it nfs-web-5ff688ccf8-7k22s -c nginx-container -- /bin/bash
```
  
When you're done, delete the deployment:
```sh
kubectl delete -f nfs-web.yaml
```

`nfs-web.yaml` file:
```yaml
# This K8s deployment creates 3 Nginx Pods and
# mount an NFS volume into "/usr/share/nginx/html" of each Pod to
# serve a simple web page.
#
# kubectl apply --validate=true --dry-run=client --filename=nfs-web.yaml
#
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nfs-web
spec:
  replicas: 3
  template:
    metadata:
      labels:
        role: web-frontend
    spec:
      containers:
      - name: nginx-container
        image: nginx
        ports:
          - name: web
            containerPort: 80
        volumeMounts:
            # name must match the volume name below
            - name: nfs
              mountPath: "/usr/share/nginx/html"
      volumes:
      - name: nfs
        nfs:
          server: debian1.example.com
          path: /data
          readOnly: true
```

# Reference

<p align="right">(<a href="#readme-top">back to top</a>)</p>
