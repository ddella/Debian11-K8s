# Add a node to a Kubernetes Cluster
This tutorial shows how to add a node to an existing Kubernetes Cluster.

## On Master Node
Log in to Kubernetes Master node and get the joining token with the command below. Tokens are usually valid for 24-hours. Chances are that this command won't return anything.
```sh
kubeadm token list
```

If no join token is available, generate a new join token using `kubeadm` command:
```sh
kubeadm token create --print-join-command
```

You should see an output similar to this. It will be the command to enter on the new node:
```
sudo kubeadm join 10.250.12.180:6443 --token owok8l.y79gg4iru06wnvse --discovery-token-ca-cert-hash sha256:9a374ad0f3b7dea59b44979241bdd0d432d9da0de35705022cb5909fee75b03d
```

## On New Worker Node
Just enter the command from the output of `kubeadm` from the master node:
```sh
sudo kubeadm join 10.250.12.180:6443 --token owok8l.y79gg4iru06wnvse --discovery-token-ca-cert-hash sha256:9a374ad0f3b7dea59b44979241bdd0d432d9da0de35705022cb5909fee75b03d
```

## Check New Worker Node
Verify that the new worker node has joined the party 🎉
```sh
kubectl get nodes -o=wide
```

Output:
```
NAME          STATUS     ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
s666dan4051   Ready      control-plane   46d   v1.27.3   10.250.12.180   <none>        Ubuntu 22.04.2 LTS   6.4.0-060400-generic   containerd://1.6.21
s666dan4151   Ready      worker          46d   v1.27.3   10.250.12.185   <none>        Ubuntu 22.04.2 LTS   6.4.0-060400-generic   containerd://1.6.21
s666dan4152   Ready      worker          46d   v1.27.3   10.250.12.186   <none>        Ubuntu 22.04.2 LTS   6.4.0-060400-generic   containerd://1.6.21
s666dan4153   Ready      worker          46d   v1.27.3   10.250.12.187   <none>        Ubuntu 22.04.2 LTS   6.4.0-060400-generic   containerd://1.6.21
s666dan4251   NotReady   <none>          22s   v1.27.3   10.250.14.185   <none>        Ubuntu 22.04.2 LTS   6.4.0-060400-generic   containerd://1.6.21
```

Node is `NotReady` because your `CNI ` has not been installed yet. Give it some time to download all the images to run the necessary containers.

## Add node role
I like to have a `ROLES` with `worker`, so I add a node role:
```sh
kubectl label node s666dan4251 node-role.kubernetes.io/worker=myworker
```

# Token list not empty
If the token list is not empty, you can re-use it but you'll need the `sha256` of the control plane CA. To get the full join command, log to the control plane and execute this script:
```sh
# IP address of the control plane
ipaddr = "10.250.12.180"
# SHA of CA certificate
sha_token = "$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //')"
# Token to join the cluster
token = "$(kubeadm token list | awk '{print $1}' | sed -n '2 p')"
# The whole join command
echo "kubeadm join $ipaddr:6443 --token=$token --discovery-token-ca-cert-hash sha256:$sha_token"
```

>**Note**:Change the 'ipaddr' 😉
