# Deep dive in Calico Routing and IPAM
Check the routing table on a Calico Pod with the command:
```sh
kubectl exec calico-node-5v9kg -n calico-system -- birdcl -s /var/run/calico/bird.ctl show route
```

>This was executed on the control plane

Your output will be different:
```
Defaulted container "calico-node" out of: calico-node, flexvol-driver (init), install-cni (init)
BIRD v0.3.3+birdv1.6.8 ready.
0.0.0.0/0          via 10.250.12.1 on ens160 [kernel1 18:38:42] * (10)
10.4.0.0/24        dev nerdctl0 [direct1 18:38:41] * (240)
10.250.10.32/28    via 10.250.12.1 on ens160 [Node_10_250_12_1 18:38:43] * (100/0) [AS65000?]
10.255.129.128/26  via 10.250.12.187 on ens160 [Mesh_10_250_12_185 18:38:42 from 10.250.12.185] * (100/0) [i]
                   via 10.250.12.187 on ens160 [Mesh_10_250_12_186 18:38:43 from 10.250.12.186] (100/0) [i]
                   via 10.250.12.187 on ens160 [Mesh_10_250_12_187 18:38:42] (100/0) [i]
                   via 10.250.12.187 on ens160 [Mesh_10_250_12_187 18:38:42] (100/0) [i]
                   via 10.250.12.187 on ens160 [kernel1 18:38:42] (10)
10.255.140.64/26   via 10.250.12.185 on ens160 [Mesh_10_250_12_185 18:38:42] * (100/0) [i]
                   via 10.250.12.185 on ens160 [Mesh_10_250_12_186 18:38:43 from 10.250.12.186] (100/0) [i]
                   via 10.250.12.185 on ens160 [Mesh_10_250_12_187 18:38:42 from 10.250.12.187] (100/0) [i]
                   via 10.250.12.185 on ens160 [Mesh_10_250_12_185 18:38:42] (100/0) [i]
                   via 10.250.12.185 on ens160 [kernel1 18:38:42] (10)
10.96.0.0/12       blackhole [static1 18:38:41] * (200)
                   via 10.250.12.186 on ens160 [Mesh_10_250_12_186 18:38:43] (100/0) [i]
                   via 10.250.12.187 on ens160 [Mesh_10_250_12_187 18:38:42] (100/0) [i]
                   via 10.250.12.185 on ens160 [Mesh_10_250_12_185 18:38:42] (100/0) [i]
10.255.108.130/32  dev cali684787e1ffe [kernel1 18:38:42] * (10)
10.255.108.131/32  dev vxlan.calico [direct1 18:38:41] * (240)
10.255.96.64/26    via 10.250.12.186 on ens160 [Mesh_10_250_12_185 18:38:42 from 10.250.12.185] * (100/0) [i]
                   via 10.250.12.186 on ens160 [Mesh_10_250_12_186 18:38:43] (100/0) [i]
                   via 10.250.12.186 on ens160 [Mesh_10_250_12_186 18:38:43] (100/0) [i]
                   via 10.250.12.186 on ens160 [Mesh_10_250_12_187 18:38:42 from 10.250.12.187] (100/0) [i]
                   via 10.250.12.186 on ens160 [kernel1 18:38:42] (10)
10.255.108.128/26  blackhole [static1 18:38:41] * (200)
                   blackhole [kernel1 18:38:42] (10)
10.255.108.129/32  dev cali9bc356ada4d [kernel1 18:38:42] * (10)
10.250.10.16/28    via 10.250.12.1 on ens160 [Node_10_250_12_1 18:38:43] * (100/0) [AS65000?]
172.17.0.0/16      dev docker0 [direct1 18:38:41] * (240)
10.250.11.0/24     via 10.250.12.1 on ens160 [Node_10_250_12_1 18:38:43] * (100/0) [AS65000?]
10.250.14.0/24     via 10.250.12.1 on ens160 [Node_10_250_12_1 18:38:43] * (100/0) [AS65000?]
10.250.12.0/24     dev ens160 [direct1 18:38:41] * (240)
                   via 10.250.12.1 on ens160 [Node_10_250_12_1 18:38:43] (100/0) [AS65000?]
```

Let's focus on the three subnets
```
10.255.129.128/26  via 10.250.12.187 on ens160
10.255.140.64/26   via 10.250.12.185 on ens160
10.255.96.64/26    via 10.250.12.186 on ens160
```

Show detailed information for IP blocks as well as pools.
```sh
sudo -E calicoctl ipam show --show-blocks
```

My output:
```
+----------+-------------------+-----------+------------+--------------+
| GROUPING |       CIDR        | IPS TOTAL | IPS IN USE |   IPS FREE   |
+----------+-------------------+-----------+------------+--------------+
| IP Pool  | 10.255.0.0/16     |     65536 | 20 (0%)    | 65516 (100%) |
| Block    | 10.255.108.128/26 |        64 | 3 (5%)     | 61 (95%)     |
| Block    | 10.255.129.128/26 |        64 | 5 (8%)     | 59 (92%)     |
| Block    | 10.255.140.64/26  |        64 | 5 (8%)     | 59 (92%)     |
| Block    | 10.255.96.64/26   |        64 | 7 (11%)    | 57 (89%)     |
+----------+-------------------+-----------+------------+--------------+
```

To provide block affinities along with IP allocation by node, use the command below:
```sh
calicoctl ipam check
```

```
Checking IPAM for inconsistencies...

Loading all IPAM blocks...
Found 4 IPAM blocks.
 IPAM block 10.255.108.128/26 affinity=host:s666dan4051:
 IPAM block 10.255.129.128/26 affinity=host:s666dan4153:
 IPAM block 10.255.140.64/26 affinity=host:s666dan4151:
 IPAM block 10.255.96.64/26 affinity=host:s666dan4152:
IPAM blocks record 20 allocations.

Loading all IPAM pools...
  10.255.0.0/16
Found 1 active IP pools.

Loading all nodes.
Found 4 node tunnel IPs.

Loading all workload endpoints.
Found 16 workload IPs.
Workloads and nodes are using 20 IPs.

Loading all handles
Looking for top (up to 20) nodes by allocations...
  s666dan4152 has 7 allocations
  s666dan4153 has 5 allocations
  s666dan4151 has 5 allocations
  s666dan4051 has 3 allocations
Node with most allocations has 7; median is 5

Scanning for IPs that are allocated but not actually in use...
Found 0 IPs that are allocated in IPAM but not actually in use.
Scanning for IPs that are in use by a workload or node but not allocated in IPAM...
Found 0 in-use IPs that are not in active IP pools.
Found 0 in-use IPs that are in active IP pools but have no corresponding IPAM allocation.

Scanning for IPAM handles with no matching IPs...
Found 0 handles with no matching IPs (and 20 handles with matches).
Scanning for IPs with missing handle...
Found 0 handles mentioned in blocks with no matching handle resource.
Check complete; found 0 problems.
```

Block affinities can also be obtained using the `blockaffinities` custom resource definition (CRD). An example is shown below with a `Go template` to output only the CIDR blocks with the nodes:
```sh
kubectl get blockaffinities -o go-template='{{- range .items -}}{{- if eq .spec.state "confirmed" -}}Node:{{.spec.node}}{{"\t"}}CIDR:{{.spec.cidr}}{{- "\n"}}{{- end -}}{{- end -}}'
```

```
Node:s666dan4051	CIDR:10.255.108.128/26
Node:s666dan4151	CIDR:10.255.140.64/26
Node:s666dan4152	CIDR:10.255.96.64/26
Node:s666dan4153	CIDR:10.255.129.128/26
```

Look at the IP address of each Pods and check that they really were allocated from Calico's IPAM:
```sh
kubectl get pods -A -o=wide
```

Output:
```
NAMESPACE          NAME                                       READY   STATUS    RESTARTS        AGE    IP               NODE          NOMINATED NODE   READINESS GATES
calico-apiserver   calico-apiserver-5d77dc756c-jdtkc          1/1     Running   2 (3d8h ago)    18d    10.255.140.122   s666dan4151   <none>           <none>
calico-apiserver   calico-apiserver-5d77dc756c-spklp          1/1     Running   1 (3d8h ago)    18d    10.255.129.157   s666dan4153   <none>           <none>
calico-system      calico-kube-controllers-656675bd4f-t6lcr   1/1     Running   1 (18d ago)     18d    10.255.108.129   s666dan4051   <none>           <none>
calico-system      calico-node-2k2b9                          1/1     Running   0               60m    10.250.12.185    s666dan4151   <none>           <none>
calico-system      calico-node-5v9kg                          1/1     Running   0               61m    10.250.12.180    s666dan4051   <none>           <none>
calico-system      calico-node-hjrjz                          1/1     Running   0               60m    10.250.12.186    s666dan4152   <none>           <none>
calico-system      calico-node-l29gc                          1/1     Running   0               61m    10.250.12.187    s666dan4153   <none>           <none>
calico-system      calico-typha-5d9685f8d6-552l4              1/1     Running   6 (3d8h ago)    18d    10.250.12.186    s666dan4152   <none>           <none>
calico-system      calico-typha-5d9685f8d6-f4nmk              1/1     Running   11 (3d8h ago)   18d    10.250.12.187    s666dan4153   <none>           <none>
calico-system      csi-node-driver-6nb9l                      2/2     Running   6 (3d8h ago)    18d    10.255.96.97     s666dan4152   <none>           <none>
calico-system      csi-node-driver-89t5b                      2/2     Running   6 (3d8h ago)    18d    10.255.129.161   s666dan4153   <none>           <none>
calico-system      csi-node-driver-cwnbq                      2/2     Running   4 (3d8h ago)    18d    10.255.140.125   s666dan4151   <none>           <none>
calico-system      csi-node-driver-zs8q7                      2/2     Running   2 (18d ago)     18d    10.255.108.130   s666dan4051   <none>           <none>
default            hello-v1-7cd64d6955-6p5zx                  2/2     Running   6 (3d8h ago)    18d    10.255.96.95     s666dan4152   <none>           <none>
default            hello-v1-7cd64d6955-rlc8g                  2/2     Running   6 (3d8h ago)    18d    10.255.96.96     s666dan4152   <none>           <none>
default            hello-v1-7cd64d6955-svb7r                  2/2     Running   4 (3d8h ago)    18d    10.255.140.124   s666dan4151   <none>           <none>
jenkins-ns         jenkins-f6f95f6f6-pstt4                    1/1     Running   0               3d5h   10.255.129.169   s666dan4153   <none>           <none>
kube-system        coredns-5d78c9869d-4dtcm                   1/1     Running   5 (3d8h ago)    36d    10.255.96.93     s666dan4152   <none>           <none>
kube-system        coredns-5d78c9869d-flsd8                   1/1     Running   5 (3d8h ago)    36d    10.255.96.94     s666dan4152   <none>           <none>
kube-system        etcd-s666dan4051                           1/1     Running   231 (18d ago)   36d    10.250.12.180    s666dan4051   <none>           <none>
kube-system        kube-apiserver-s666dan4051                 1/1     Running   213 (18d ago)   36d    10.250.12.180    s666dan4051   <none>           <none>
kube-system        kube-controller-manager-s666dan4051        1/1     Running   222 (18d ago)   36d    10.250.12.180    s666dan4051   <none>           <none>
kube-system        kube-proxy-7rqv9                           1/1     Running   5 (3d8h ago)    36d    10.250.12.186    s666dan4152   <none>           <none>
kube-system        kube-proxy-gm7g6                           1/1     Running   4 (3d8h ago)    36d    10.250.12.185    s666dan4151   <none>           <none>
kube-system        kube-proxy-sqtpd                           1/1     Running   3 (18d ago)     36d    10.250.12.180    s666dan4051   <none>           <none>
kube-system        kube-proxy-vgbqb                           1/1     Running   6 (3d8h ago)    36d    10.250.12.187    s666dan4153   <none>           <none>
kube-system        kube-scheduler-s666dan4051                 1/1     Running   238 (18d ago)   36d    10.250.12.180    s666dan4051   <none>           <none>
nginx-jenkins-ns   nginx-jenkins-dp-75684b8dbc-g75qr          1/1     Running   1 (3d8h ago)    9d     10.255.140.126   s666dan4151   <none>           <none>
nginx-jenkins-ns   nginx-jenkins-dp-75684b8dbc-jc8lr          1/1     Running   2 (3d8h ago)    9d     10.255.96.98     s666dan4152   <none>           <none>
nginx-jenkins-ns   nginx-jenkins-dp-75684b8dbc-zs584          1/1     Running   5 (3d8h ago)    9d     10.255.129.162   s666dan4153   <none>           <none>
tigera-operator    tigera-operator-58f95869d6-8nghh           1/1     Running   6 (3d8h ago)    18d    10.250.12.187    s666dan4153   <none>           <none>
```

