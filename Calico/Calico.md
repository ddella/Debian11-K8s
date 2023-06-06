# Install Calico

1. Get the latest version number of `calico`:
```sh
VER=$(curl -s https://api.github.com/repos/projectcalico/calico/releases/latest | grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo $VER
```

2. Download Tigera Calico operator and custom resource definitions manifest:
```sh
curl -LO https://raw.githubusercontent.com/projectcalico/calico/v${VER}/manifests/tigera-operator.yaml
```

3. Install the Tigera Calico operator and custom resource definitions:
```sh
kubectl create -f tigera-operator.yaml
```
 
4. Download Tigera Calico necessary custom resource definitions manifest:
```sh
curl -LO https://raw.githubusercontent.com/projectcalico/calico/v${VER}/manifests/custom-resources.yaml
```

5. You need to install Tigera Calico custom resource definitions but before make sure the `cidr` value matches the one you passed to `kubeadm init --pod-network-cidr=10.255.0.0/16 ...` when you configured you K8s cluster. See below my `custom-resources.yaml` file that I edited:

To retreive the `cidr` value you passed to `kubeadm init ...` when you configured you K8s cluster, type the command:
```sh
kubectl cluster-info dump | grep -m 1 cluster-cidr
```

You should see the following output (your milage may vary 😀). That's the value that you need to edit in the file `custom-resources.yaml`:
```
"--cluster-cidr=10.255.0.0/16",
```

File `custom-resources.yaml`
```
[...]
    ipPools:
    - blockSize: 26
      # cidr: 192.168.0.0/16
      cidr: 10.255.0.0/16
[...]
```

Create the custom resource definitions:
```sh
kubectl create -f custom-resources.yaml
```

6. Confirm that the operator pod is running with the following command:
```sh
kubectl get pods -n tigera-operator
```

You should see the following output:
```
NAME                               READY   STATUS    RESTARTS   AGE
tigera-operator-58f95869d6-d6m2f   1/1     Running   0          30m
```

7. Confirm that all of the pods are running with the following command:
```sh
watch kubectl get pods -n calico-system 
```

>Be patient here, K8s needs to downloads the images on Internet. It took me 10 minutes to have all the Pods running. You can use Ctrl+C to exit from the watch command once all of the Calico pods have come up.

You should see the following output when everything in downloaded and running:
```
NAME                                       READY   STATUS    RESTARTS   AGE
calico-kube-controllers-7b89497fbf-pgqcd   1/1     Running   0          10m
calico-node-gjn54                          1/1     Running   0          10m
calico-node-smf5j                          1/1     Running   0          10m
calico-node-sqtdn                          1/1     Running   0          10m
calico-node-w6bh4                          1/1     Running   0          10m
calico-typha-6fcb57fbcf-5898q              1/1     Running   0          10m
calico-typha-6fcb57fbcf-rpfgs              1/1     Running   0          10m
csi-node-driver-4prxh                      2/2     Running   0          10m
csi-node-driver-jnvlp                      2/2     Running   0          10m
csi-node-driver-p5pw6                      2/2     Running   0          10m
csi-node-driver-x6hc8                      2/2     Running   0          10m
```

From here we can see that there are different pods that are deployed.
- `calico-node`: Calico-node runs on every Kubernetes cluster node as a DaemonSet. It is responsible for enforcing network policy, setting up routes on the nodes, plus managing any virtual interfaces for IPIP, VXLAN, or WireGuard.
- `calico-typha`: Typha is as a stateful proxy for the Kubernetes API server. It's used by every calico-node pod to query and watch Kubernetes resources without putting excessive load on the Kubernetes API server.  The Tigera Operator automatically scales the number of Typha instances as the cluster size grows.
- `calico-kube-controllers`: Runs a variety of Calico specific controllers that automate synchronization of resources. For example, when a Kubernetes node is deleted, it tidies up any IP addresses or other Calico resources associated with the node.

8. Validating the Calico installation
Following the configuration of the installation resource, Calico will begin deploying onto your cluster. This can be validated by running the following command:

```sh
kubectl get tigerastatus/calico
```

The output from the command when the installation is complete is:
```
NAME     AVAILABLE   PROGRESSING   DEGRADED   SINCE
calico   True        False         False      47m
```

9. Reviewing Node Health with the following command:
```sh
kubectl get nodes -o=wide
```

You should see the following output:
```
NAME                     STATUS   ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
k8smaster1.isociel.com   Ready    control-plane   6d20h   v1.27.2   192.168.13.30   <none>        Ubuntu 22.04.2 LTS   6.3.4-060304-generic   containerd://1.6.21
k8sworker1.isociel.com   Ready    worker          6d20h   v1.27.2   192.168.13.35   <none>        Ubuntu 22.04.2 LTS   6.3.4-060304-generic   containerd://1.6.21
k8sworker2.isociel.com   Ready    worker          6d20h   v1.27.2   192.168.13.36   <none>        Ubuntu 22.04.2 LTS   6.3.4-060304-generic   containerd://1.6.21
k8sworker3.isociel.com   Ready    worker          6d20h   v1.27.2   192.168.13.37   <none>        Ubuntu 22.04.2 LTS   6.3.4-060304-generic   containerd://1.6.21
```

Now we can see that our Kubernetes nodes have a status of `Ready` and are operational. Calico is now installed on your cluster.

## Calico installation Reference
[Project Calico](https://github.com/projectcalico/calico)
[Calico Quick Start](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart)
[Calico API](https://docs.tigera.io/calico/latest/reference/installation/api)


# Install `calicoctl` as a binary and as a `kubectl` plugin on a single host
Use the following command to download the `calicoctl` binary file:
```sh
curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o calicoctl
```

Set the file to be executable, set owner and move it to `/usr/local/bin/`:
```sh
chmod +x ./calicoctl
sudo mv calicoctl /usr/local/bin
sudo chown root:adm /usr/local/bin/calicoctl
```

To be able to use it as a `kubectl` plugin, just symlink it to the binary you just installed:
```sh
sudo ln -s /usr/local/bin/calicoctl /usr/local/bin/kubectl-calico
sudo chown root:adm /usr/local/bin/kubectl-calico
```

Verify the plugin works:
```sh
kubectl calico -h
```

You can now run any `calicoctl` subcommands through `kubectl calico`.

You should be able to use it:
```sh
calicoctl version
```

You should see the following output:
```
Client Version:    v3.26.0
Git commit:        8b103f46f
Cluster Version:   v3.26.0
Cluster Type:      typha,kdd,k8s,operator,bgp,kubeadm
```

## `calicoctl` with `sudo`
If you use sudo for commands, remember that your environment variables are not transferred to the sudo environment. You must run sudo with the `-E` flag to include your environment variables:

```sh
sudo -E calicoctl node diags
```

## Reference
[calicoctl](https://docs.tigera.io/calico/latest/reference/calicoctl/)

# Install Calico API server (Don't worry nothing to do here 😉)
In previous releases, `calicoctl` has been required to manage Calico API resources in the `projectcalico.org/v3` API group. The `calicoctl` CLI tool provides important validation and defaulting on these APIs. The Calico API server performs that defaulting and validation server-side, exposing the same API semantics without a dependency on `calicoctl`. Starting in Calico v3.20.0, new operator-based installations of Calico include the API server component by default, so there's no need to install it. As of this writing the latest Calico is v3.26.0.

Confirm that the API server appears as `Available` with the following command.
```sh
kubectl get tigerastatus apiserver
```

You should see the following output:
```
NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver   True        False         False      16m
```

You should see the API server pod become ready, and Calico API resources become available. You can check whether the APIs are available with the following command:

```sh
kubectl api-resources | grep '\sprojectcalico.org'
```

You should see the following output:
```
bgpconfigurations                  bgpconfig,bgpconfigs                            projectcalico.org/v3                   false        BGPConfiguration
bgpfilters                                                                         projectcalico.org/v3                   false        BGPFilter
bgppeers                                                                           projectcalico.org/v3                   false        BGPPeer
blockaffinities                    blockaffinity,affinity,affinities               projectcalico.org/v3                   false        BlockAffinity
caliconodestatuses                 caliconodestatus                                projectcalico.org/v3                   false        CalicoNodeStatus
clusterinformations                clusterinfo                                     projectcalico.org/v3                   false        ClusterInformation
felixconfigurations                felixconfig,felixconfigs                        projectcalico.org/v3                   false        FelixConfiguration
globalnetworkpolicies              gnp,cgnp,calicoglobalnetworkpolicies            projectcalico.org/v3                   false        GlobalNetworkPolicy
globalnetworksets                                                                  projectcalico.org/v3                   false        GlobalNetworkSet
hostendpoints                      hep,heps                                        projectcalico.org/v3                   false        HostEndpoint
ipamconfigurations                 ipamconfig                                      projectcalico.org/v3                   false        IPAMConfiguration
ippools                                                                            projectcalico.org/v3                   false        IPPool
ipreservations                                                                     projectcalico.org/v3                   false        IPReservation
kubecontrollersconfigurations                                                      projectcalico.org/v3                   false        KubeControllersConfiguration
networkpolicies                    cnp,caliconetworkpolicy,caliconetworkpolicies   projectcalico.org/v3                   true         NetworkPolicy
networksets                        netsets                                         projectcalico.org/v3                   true         NetworkSet
profiles                                                                           projectcalico.org/v3                   false        Profile
```

You can use `kubectl` to interact with the Calico APIs. For example, you can view IP pools with the command:
```sh
kubectl get ippools
```
You should see output that looks like this:
```
NAME                  CREATED AT
default-ipv4-ippool   2023-06-03T14:01:55Z
```
## Reference
[Calico API Server](https://docs.tigera.io/calico/latest/operations/install-apiserver)


# Tests with `calicoctl`
The `calicoctl` command line interface provides a number of resource management commands to allow you to create, modify, delete, and view the different Calico resources. This section is a command line reference for `calicoctl`, organized based on the command hierarchy.

The full list of resources that can be managed, including a description of each, is described in the [Resource definitions](https://docs.tigera.io/calico/latest/reference/resources/overview) section.

```sh
sudo kubectl calico node status
```

You should see output that looks like this:
```
Calico process is running.

IPv4 BGP status
+--------------+-------------------+-------+----------+-------------+
| PEER ADDRESS |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+--------------+-------------------+-------+----------+-------------+
| 10.0.0.187   | node-to-node mesh | up    | 14:02:10 | Established |
| 10.0.3.21    | node-to-node mesh | up    | 14:02:08 | Established |
| 10.0.2.129   | node-to-node mesh | up    | 14:02:11 | Established |
+--------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```

## Reference
[calicoctl overview](https://docs.tigera.io/calico/latest/reference/calicoctl/overview)

# Edit the Calico installation

DON'T DO THIS 😱
```sh
kubectl edit installation default
```

## Reference
[Edit Calico](https://docs.tigera.io/calico/latest/network-policy/non-privileged)

# Troubleshooting commands
Use command line tools to get status and troubleshoot.

- Hosts
- Kubernetes
- Calico components
- Routing
- Network policy

## Hosts
### Verify number of nodes in a cluster

```sh
kubectl get nodes
```

Verify calico-node pods are running on every node, and are in a healthy state
```sh
kubectl get pods -n calico-system -o=wide | grep calico-node-
```

You should see output that looks like this:
```
calico-node-gjn54                          1/1     Running   0          3h10m   192.168.13.37   k8sworker3.isociel.com   <none>           <none>
calico-node-smf5j                          1/1     Running   0          3h10m   192.168.13.36   k8sworker2.isociel.com   <none>           <none>
calico-node-sqtdn                          1/1     Running   0          3h10m   192.168.13.30   k8smaster1.isociel.com   <none>           <none>
calico-node-w6bh4                          1/1     Running   0          3h10m   192.168.13.35   k8sworker1.isociel.com   <none>           <none>
```

### Collect Calico diagnostic logs
```sh
sudo calicoctl node diags
```

>**Note:** Lots of utilities not installed


### Verify Kubernetes API server is running
```sh
kubectl cluster-info
```

You should see output that looks like this:
```
Kubernetes control plane is running at https://192.168.13.30:6443
CoreDNS is running at https://192.168.13.30:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

### Verify Kubernetes kube-dns is working
```sh
kubectl get svc
```

You should see output that looks like this:
```
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.96.0.1    <none>        443/TCP   7d
```

You can start the multitool container for troubleshooting with the command:
```sh
kubectl run multitool --image=praqma/network-multitool
```

```sh
kubectl exec -it multitool -- bash
```

```sh
curl -I -k https://kubernetes
```

You should see output that looks like this:
```
HTTP/2 403 
audit-id: 5dbcf42f-282d-44b5-9314-721bd0942a58
cache-control: no-cache, private
content-type: application/json
x-content-type-options: nosniff
x-kubernetes-pf-flowschema-uid: df4ded28-11dd-4965-aed6-2e9df49ca883
x-kubernetes-pf-prioritylevel-uid: 47c2a755-216d-4577-b1e3-dc3853d093bd
content-length: 218
date: Sat, 03 Jun 2023 18:11:30 GMT
```

```sh
nslookup google.com
```

You should see output that looks like this:
```
Server:		10.96.0.10
Address:	10.96.0.10#53

Non-authoritative answer:
Name:	google.com
Address: 172.253.115.113
[...]
Name:	google.com
Address: 2607:f8b0:4004:c1b::66
```

You can delete the multitool Pod with the command:
```sh
kubectl delete pods multitool
```

### Verify that kubelet is running on the node with the correct flags
Check for errors:
```sh
systemctl status kubelet
```

If there is a problem, check the journal with the command:
```sh
journalctl -u kubelet | tail
```

## Calico components

### View Calico CNI configuration on a node
```sh
sudo cat /etc/cni/net.d/10-calico.conflist
```

### Verify `calicoctl` matches cluster
The cluster version and type must match the calicoctl version.

```sh
calicoctl version
```

You should see output that looks like this:
```
```

### Check tigera operator status
```sh
kubectl get tigerastatus
```

You should see output that looks like this:
```
NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver   True        False         False      3h33m
calico      True        False         False      3h33m
```

Check if operator pod is running
```sh
kubectl get pod -n tigera-operator
```

You should see output that looks like this:
```
NAME                               READY   STATUS    RESTARTS   AGE
tigera-operator-58f95869d6-d6m2f   1/1     Running   0          3h35m
```

View calico nodes
```sh
kubectl get pod -n calico-system -o wide
```

You should see output that looks like this:
```
NAME                                       READY   STATUS    RESTARTS   AGE     IP              NODE                     NOMINATED NODE   READINESS GATES
calico-kube-controllers-7b89497fbf-pgqcd   1/1     Running   0          3h35m   10.255.74.65    k8smaster1.isociel.com   <none>           <none>
calico-node-gjn54                          1/1     Running   0          3h35m   192.168.13.37   k8sworker3.isociel.com   <none>           <none>
calico-node-smf5j                          1/1     Running   0          3h35m   192.168.13.36   k8sworker2.isociel.com   <none>           <none>
calico-node-sqtdn                          1/1     Running   0          3h35m   192.168.13.30   k8smaster1.isociel.com   <none>           <none>
calico-node-w6bh4                          1/1     Running   0          3h35m   192.168.13.35   k8sworker1.isociel.com   <none>           <none>
calico-typha-6fcb57fbcf-5898q              1/1     Running   0          3h35m   192.168.13.37   k8sworker3.isociel.com   <none>           <none>
calico-typha-6fcb57fbcf-rpfgs              1/1     Running   0          3h35m   192.168.13.35   k8sworker1.isociel.com   <none>           <none>
csi-node-driver-4prxh                      2/2     Running   0          3h35m   10.255.153.65   k8sworker2.isociel.com   <none>           <none>
csi-node-driver-jnvlp                      2/2     Running   0          3h35m   10.255.74.66    k8smaster1.isociel.com   <none>           <none>
csi-node-driver-p5pw6                      2/2     Running   0          3h35m   10.255.77.129   k8sworker1.isociel.com   <none>           <none>
csi-node-driver-x6hc8                      2/2     Running   0          3h35m   10.255.18.129   k8sworker3.isociel.com   <none>           <none>
```

### View Calico installation parameters
```sh
kubectl get installation -o yaml
```

### Run commands across multiple nodes
```sh
export THE_COMMAND_TO_RUN=date && for calinode in `kubectl get pod -o wide -n calico-system | grep calico-node | awk '{print $1}'`; do echo $calinode; echo "-----"; kubectl exec -n calico-system $calinode -- $THE_COMMAND_TO_RUN; printf "\n"; done
```

You should see output that looks like this:
```
calico-node-gjn54
-----
Defaulted container "calico-node" out of: calico-node, flexvol-driver (init), install-cni (init)
Sat Jun  3 17:38:29 UTC 2023

calico-node-smf5j
-----
Defaulted container "calico-node" out of: calico-node, flexvol-driver (init), install-cni (init)
Sat Jun  3 17:38:29 UTC 2023

calico-node-sqtdn
-----
Defaulted container "calico-node" out of: calico-node, flexvol-driver (init), install-cni (init)
Sat Jun  3 17:38:29 UTC 2023

calico-node-w6bh4
-----
Defaulted container "calico-node" out of: calico-node, flexvol-driver (init), install-cni (init)
Sat Jun  3 17:38:30 UTC 2023
```

### View pod info
```sh
kubectl describe pods <pod_name>  -n <namespace>
```

### View logs of a pod
```sh
kubectl logs <pod_name>  -n <namespace>
```

### View kubelet logs
```sh
journalctl -u kubelet | tail
```

## Routing

### Verify routing table on the node
```sh
ip route
```

You should see output that looks like this:
```
default via 192.168.13.1 dev ens33 proto static 
10.255.18.128/26 via 192.168.13.37 dev ens33 proto 80 onlink 
blackhole 10.255.74.64/26 proto 80 
10.255.74.67 dev cali8319f348d9d scope link 
10.255.74.68 dev calie9b731769ab scope link 
10.255.74.69 dev cali21312e9f9cd scope link 
10.255.74.70 dev cali039b6545292 scope link 
10.255.77.128/26 via 192.168.13.35 dev ens33 proto 80 onlink 
10.255.153.64/26 via 192.168.13.36 dev ens33 proto 80 onlink 
192.168.13.0/24 dev ens33 proto kernel scope link src 192.168.13.30 
```

### Verify BGP peer status
```sh
sudo calicoctl node status
```

You should see output that looks like this:
```
Calico process is running.

IPv4 BGP status
+--------------+-------------------+-------+----------+-------------+
| PEER ADDRESS |     PEER TYPE     | STATE |  SINCE   |    INFO     |
+--------------+-------------------+-------+----------+-------------+
| 10.0.0.187   | node-to-node mesh | up    | 14:02:11 | Established |
| 10.0.3.21    | node-to-node mesh | up    | 14:02:09 | Established |
| 10.0.2.129   | node-to-node mesh | up    | 14:02:12 | Established |
+--------------+-------------------+-------+----------+-------------+

IPv6 BGP status
No IPv6 peers found.
```

### Verify overlay configuration
```sh
kubectl get ippools default-ipv4-ippool -o yaml
```

You should see output that looks like this:
```
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  creationTimestamp: "2023-06-03T14:01:55Z"
  name: default-ipv4-ippool
  resourceVersion: "611611"
  uid: e3f30554-14cb-4f44-b49d-390ddf4148c0
spec:
  allowedUses:
  - Workload
  - Tunnel
  blockSize: 26
  cidr: 10.255.0.0/16
  ipipMode: Never
  natOutgoing: true
  nodeSelector: all()
  vxlanMode: CrossSubnet
```

### Verify bgp learned routes
```sh
ip r | grep bird
```

You should see output that looks like this:
```
[Empty for my cluster???]
```

### Verify BIRD routing table
Note: The BIRD routing table gets pushed to node routing tables.

Choose one of the nodes (if you have multiple node in your cluster):
```sh
kubectl get pods -n calico-system -o=name | grep calico-node | awk -F "/" '{print $2}'
```

```sh
kubectl exec -it -n calico-system calico-node-gjn54 -- /bin/bash
```

You should see output that looks like this:
```
Defaulted container "calico-node" out of: calico-node, flexvol-driver (init), install-cni (init)
[root@k8sworker3 /]# bird
bird             bird-wrapper.sh  bird6            birdcl           birdcl6          
[root@k8sworker3 /]# birdcl
BIRD v0.3.3+birdv1.6.8 ready.
bird> show route
0.0.0.0/0          via 192.168.13.1 on ens33 [kernel1 17:48:57] * (10)
192.168.13.0/24    dev ens33 [direct1 17:48:56] * (240)
10.255.153.64/26   via 192.168.13.36 on ens33 [Mesh_192_168_13_30 17:48:59 from 192.168.13.30] * (100/0) [i]
                   via 192.168.13.36 on ens33 [Mesh_192_168_13_35 17:49:10 from 192.168.13.35] (100/0) [i]
                   via 192.168.13.36 on ens33 [Mesh_192_168_13_36 17:48:58] (100/0) [i]
                   via 192.168.13.36 on ens33 [Mesh_192_168_13_36 17:48:58] (100/0) [i]
                   via 192.168.13.36 on ens33 [kernel1 17:48:58] (10)
10.255.77.128/26   via 192.168.13.35 on ens33 [Mesh_192_168_13_30 17:49:00 from 192.168.13.30] * (100/0) [i]
                   via 192.168.13.35 on ens33 [Mesh_192_168_13_35 17:49:08] (100/0) [i]
                   via 192.168.13.35 on ens33 [Mesh_192_168_13_35 17:49:00] (100/0) [i]
                   via 192.168.13.35 on ens33 [Mesh_192_168_13_36 17:48:58 from 192.168.13.36] (100/0) [i]
                   via 192.168.13.35 on ens33 [kernel1 17:48:57] (10)
10.255.74.64/26    via 192.168.13.30 on ens33 [Mesh_192_168_13_30 17:48:58] * (100/0) [i]
                   via 192.168.13.30 on ens33 [Mesh_192_168_13_35 17:49:08 from 192.168.13.35] (100/0) [i]
                   via 192.168.13.30 on ens33 [Mesh_192_168_13_30 17:49:00] (100/0) [i]
                   via 192.168.13.30 on ens33 [Mesh_192_168_13_36 17:48:58 from 192.168.13.36] (100/0) [i]
                   via 192.168.13.30 on ens33 [kernel1 17:48:58] (10)
10.255.18.136/32   dev cali8e8336b596b [kernel1 17:49:08] * (10)
10.255.18.128/26   blackhole [static1 17:48:56] * (200)
                   blackhole [kernel1 17:48:57] (10)
10.255.18.128/32   dev vxlan.calico [direct1 17:48:57] * (240)
10.255.18.133/32   dev cali917da1ebb84 [kernel1 17:48:57] * (10)
10.255.18.132/32   dev cali769b9281ac4 [kernel1 17:48:57] * (10)
10.255.18.135/32   dev cali2c557f8ef37 [kernel1 17:49:05] * (10)
10.255.18.134/32   dev cali4a703f13391 [kernel1 17:48:57] * (10)
```

## Network policy
```sh
calicoctl get nodes
```

You should see output that looks like this:
```
NAME                     
k8smaster1.isociel.com   
k8sworker1.isociel.com   
k8sworker2.isociel.com   
k8sworker3.isociel.com   
```

View the Calico host endpoint:
```sh
calicoctl get hostendpoint -o yaml
```

You should see output that looks like this:
```
apiVersion: projectcalico.org/v3
items: []
kind: HostEndpointList
metadata:
  resourceVersion: "653021"
```

View all the Calico network policies that were created for the cluster. This list includes policies that might not apply to any pods or hosts yet. For a Calico policy to be enforced, a Kubernetes pod or Calico HostEndpoint must exist that matches the selector that in the Calico network policy.

Network policies are scoped to specific namespaces:
```sh
kubectl get NetworkPolicy --all-namespaces -o wide
```

You should see output that looks like this:
```
NAMESPACE          NAME              POD-SELECTOR     AGE
calico-apiserver   allow-apiserver   apiserver=true   5h26m
yaobank            database-policy   app=database     58s
```

Global network policies are not scoped to specific namespaces:
```sh
calicoctl get GlobalNetworkPolicy -o wide
```

You should see output that looks like this:
```
NAME                 ORDER   SELECTOR   
default-app-policy   <nil>              
```

View details for a network policy:
```sh
kubectl get NetworkPolicy -o yaml database-policy --namespace yaobank
```

You should see output that looks like this:
```
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  creationTimestamp: "2023-06-03T19:28:13Z"
  generation: 1
  name: database-policy
  namespace: yaobank
  resourceVersion: "654231"
  uid: ad67716a-db5b-4c11-b41b-54a094a44690
spec:
  egress:
  - {}
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: summary
    ports:
    - port: 2379
      protocol: TCP
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  - Egress
status: {}
```

View the details of all global network policies for the cluster:
```sh
calicoctl get GlobalNetworkPolicy -o yaml
```

You should see output that looks like this:
```
apiVersion: projectcalico.org/v3
items:
- apiVersion: projectcalico.org/v3
  kind: GlobalNetworkPolicy
  metadata:
    creationTimestamp: "2023-06-03T19:10:17Z"
    name: default-app-policy
    resourceVersion: "651967"
    uid: def3ad9b-a734-4498-a20a-3869dee5caaf
  spec:
    egress:
    - action: Allow
      destination:
        ports:
        - 53
        selector: k8s-app == "kube-dns"
      protocol: UDP
      source: {}
    namespaceSelector: has(projectcalico.org/name) && projectcalico.org/name not in
      {"kube-system", "calico-system"}
    types:
    - Ingress
    - Egress
kind: GlobalNetworkPolicyList
metadata:
  resourceVersion: "653148"
```
# Create Host Endpoints
Let’s now create the Host Endpoints, allowing Calico to start policy enforcement on **node** interfaces. If Calico can't create the `Host Endpoints`, the Global Network Policy won't be enforced.

First, verify there no existing Host Endpoints:
```sh
daniel@k8smaster1 ~ $ calicoctl get heps
```

Example output:
```sh
NAME   NODE
```

Now let’s configure Calico to automatically create Host Endpoints for Kubernetes nodes:
```sh
daniel@k8smaster1 ~ $ calicoctl patch kubecontrollersconfiguration default --patch='{"spec": {"controllers": {"node": {"hostEndpoint": {"autoCreate": "Enabled"}}}}}'
Successfully patched 1 'KubeControllersConfiguration' resource
```

Example output:
```sh
daniel@k8smaster1 ~ $ calicoctl get heps
NAME                              NODE                     
k8smaster1.isociel.com-auto-hep   k8smaster1.isociel.com   
k8sworker1.isociel.com-auto-hep   k8sworker1.isociel.com   
k8sworker2.isociel.com-auto-hep   k8sworker2.isociel.com   
k8sworker3.isociel.com-auto-hep   k8sworker3.isociel.com   
```

# Get Calico version
To find the Calico version that is being used, run the following command:
```sh
calicoctl version
```

You should see output that looks like this:
```
Client Version:    v3.26.0
Git commit:        8b103f46f
Cluster Version:   v3.26.0
Cluster Type:      typha,kdd,k8s,operator,bgp,kubeadm
```


Or run this command if not running `calicoctl`:
```sh
kubectl get clusterinfo -o yaml
```

You should see output that looks like this:
```
apiVersion: v1
items:
- apiVersion: projectcalico.org/v3
  kind: ClusterInformation
  metadata:
    creationTimestamp: "2023-06-03T14:01:32Z"
    name: default
    resourceVersion: "611612"
    uid: 85daf4ec-8826-46da-aa8b-9aa6f307666d
  spec:
    calicoVersion: v3.26.0
    clusterGUID: 3ba9573ae1ec4ef6b65a658a0583196d
    clusterType: typha,kdd,k8s,operator,bgp,kubeadm
    datastoreReady: true
kind: List
metadata:
  resourceVersion: ""
```

# Reference
[Tigera Troubleshoot Commands](https://docs.tigera.io/calico/latest/operations/troubleshoot/commands)


