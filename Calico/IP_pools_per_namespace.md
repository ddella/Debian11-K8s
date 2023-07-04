# Assign IP pools per namespace

## Verify that you are using Calico IPAM
If you are not sure which IPAM your cluster is using, the way to tell depends on install method. If you followed Calico's recommendation, use the commandL
```sh
kubectl get installation default -o go-template --template '{{.spec.cni.ipam.type}}{{"\n"}}'
```

Output should be:
```
Calico
```


## Step 1: Create the IP pools
Let’s start by creating the IP pools for our cluster – one for each namespace we intend to use. In this example, we’ll create two. To do this, create a manifest file `pools.yaml` with the following contents:

```sh
cat > pools.yaml <<EOF
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: external-pool
spec:
  cidr: 10.64.0.0/20
  blockSize: 26
  ipipMode: Never
  natOutgoing: true
  vxlanMode: CrossSubnet
---
apiVersion: projectcalico.org/v3
kind: IPPool
metadata:
  name: internal-pool
spec:
  cidr: 10.64.16.0/20
  blockSize: 26
  ipipMode: Never
  natOutgoing: true
  vxlanMode: CrossSubnet
EOF
```

Then, use the `calicoctl` CLI tool to configure the pools in Calico:
```sh
calicoctl apply -f pools.yaml
```

Verify that the two pools have been created:
```sh
calicoctl get ippool -o wide
```

Output:
```
NAME                  CIDR            NAT    IPIPMODE   VXLANMODE     DISABLED   DISABLEBGPEXPORT   SELECTOR   
default-ipv4-ippool   10.255.0.0/16   true   Never      CrossSubnet   false      false              all()      
external-pool         10.64.0.0/20    true   Never      CrossSubnet   false      false              all()      
internal-pool         10.64.16.0/20   true   Never      CrossSubnet   false      false              all()      
```

We just created two new IP pools. The external pool is limited to 4096 addresses in total. The pools have the blockSize option set to 26, meaning that blocks allocated from those pools will be /26 CIDR blocks containing 64 addresses each.

## Step 2: Assign each pool to a namespace
Now that we’ve created the pools, we can assign each one to a different Kubernetes namespace.

First, create two namespaces using `kubectl`:
```sh
kubectl create namespace external-ns
kubectl create namespace internal-ns
```

Then `annotate` each namespace, telling Calico to use only the specified pools:
```sh
kubectl annotate namespace external-ns "cni.projectcalico.org/ipv4pools"='["external-pool"]'
kubectl annotate namespace internal-ns "cni.projectcalico.org/ipv4pools"='["internal-pool"]'
```

## Step 3: Create some pods
Now that we’ve configured the new namespaces, let’s launch some pods in each. In this example, we’ll launch three nginx pods in each namespace with a simple deployment.

```sh
cat > nginx-dp.yaml <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: external-ns
spec:
  selector:
    matchLabels:
      app: nginx-external
  replicas: 9
  template:
    metadata:
      labels:
        app: nginx-external
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: internal-ns
spec:
  selector:
    matchLabels:
      app: nginx-internal
  replicas: 9
  template:
    metadata:
      labels:
        app: nginx-internal
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
EOF
```

Then, use the `kubectl` CLI tool to configure the deployment in Kubernetes:
```sh
kubectl create -f nginx-dp.yaml
```

## Step 4: Check the IP of the Pods
Using `kubectl`, you can now view the assigned IP addresses:

you’ll see that the pods in `external-ns` have IPs in:
- 10.64.0.64/26 
- 10.64.1.128/26
- 10.64.12.64/26

whereas pods within `internal-ns` have IPs in:
- 10.64.16.64/26
- 10.64.17.128/26
- 10.64.28.64/26

```sh
kubectl get pods -o wide -n external-ns
```

Output:
```
NAME                               READY   STATUS    RESTARTS   AGE   IP            NODE          NOMINATED NODE   READINESS GATES
nginx-deployment-8bd69cc8d-b2bxx   1/1     Running   0          7s    10.64.12.65   s666dan4151   <none>           <none>
nginx-deployment-8bd69cc8d-bnggs   1/1     Running   0          7s    10.64.0.65    s666dan4152   <none>           <none>
nginx-deployment-8bd69cc8d-d2rzj   1/1     Running   0          7s    10.64.12.66   s666dan4151   <none>           <none>
nginx-deployment-8bd69cc8d-dfwqt   1/1     Running   0          7s    10.64.12.64   s666dan4151   <none>           <none>
nginx-deployment-8bd69cc8d-dgr56   1/1     Running   0          7s    10.64.1.130   s666dan4153   <none>           <none>
nginx-deployment-8bd69cc8d-k7xhh   1/1     Running   0          7s    10.64.1.128   s666dan4153   <none>           <none>
nginx-deployment-8bd69cc8d-n2lk7   1/1     Running   0          7s    10.64.0.66    s666dan4152   <none>           <none>
nginx-deployment-8bd69cc8d-tbcw2   1/1     Running   0          7s    10.64.0.64    s666dan4152   <none>           <none>
nginx-deployment-8bd69cc8d-wpdhr   1/1     Running   0          7s    10.64.1.129   s666dan4153   <none>           <none>
```

```sh
kubectl get pods -o wide -n internal-ns
```

Output:
```
NAME                                READY   STATUS    RESTARTS   AGE   IP             NODE          NOMINATED NODE   READINESS GATES
nginx-deployment-5596c58d6b-64jl6   1/1     Running   0          7m28s   10.64.28.65    s666dan4151   <none>           <none>
nginx-deployment-5596c58d6b-8mhr4   1/1     Running   0          7m28s   10.64.16.66    s666dan4152   <none>           <none>
nginx-deployment-5596c58d6b-hr6z5   1/1     Running   0          7m28s   10.64.16.64    s666dan4152   <none>           <none>
nginx-deployment-5596c58d6b-l5g5c   1/1     Running   0          7m28s   10.64.16.65    s666dan4152   <none>           <none>
nginx-deployment-5596c58d6b-lhx64   1/1     Running   0          7m28s   10.64.17.128   s666dan4153   <none>           <none>
nginx-deployment-5596c58d6b-qvlr2   1/1     Running   0          7m28s   10.64.28.66    s666dan4151   <none>           <none>
nginx-deployment-5596c58d6b-t2zhj   1/1     Running   0          7m28s   10.64.17.130   s666dan4153   <none>           <none>
nginx-deployment-5596c58d6b-t9jtn   1/1     Running   0          7m28s   10.64.28.64    s666dan4151   <none>           <none>
nginx-deployment-5596c58d6b-zsn7c   1/1     Running   0          7m28s   10.64.17.129   s666dan4153   <none>           <none>
```

## Step 5:

```sh
calicoctl ipam show
```

Output:
```
+----------+---------------+-----------+------------+--------------+
| GROUPING |     CIDR      | IPS TOTAL | IPS IN USE |   IPS FREE   |
+----------+---------------+-----------+------------+--------------+
| IP Pool  | 10.255.0.0/16 |     65536 | 36 (0%)    | 65500 (100%) |
| IP Pool  | 10.64.0.0/20  |      4096 | 9 (0%)     | 4087 (100%)  |
| IP Pool  | 10.64.16.0/20 |      4096 | 9 (0%)     | 4087 (100%)  |
+----------+---------------+-----------+------------+--------------+
```

```sh
calicoctl ipam show --show-blocks
```

Output:
```
+----------+-------------------+-----------+------------+--------------+
| GROUPING |       CIDR        | IPS TOTAL | IPS IN USE |   IPS FREE   |
+----------+-------------------+-----------+------------+--------------+
| IP Pool  | 10.255.0.0/16     |     65536 | 36 (0%)    | 65500 (100%) |
| Block    | 10.255.108.128/26 |        64 | 3 (5%)     | 61 (95%)     |
| Block    | 10.255.129.128/26 |        64 | 8 (12%)    | 56 (88%)     |
| Block    | 10.255.140.64/26  |        64 | 13 (20%)   | 51 (80%)     |
| Block    | 10.255.96.64/26   |        64 | 12 (19%)   | 52 (81%)     |
| IP Pool  | 10.64.0.0/20      |      4096 | 9 (0%)     | 4087 (100%)  |
| Block    | 10.64.0.64/26     |        64 | 3 (5%)     | 61 (95%)     |
| Block    | 10.64.1.128/26    |        64 | 3 (5%)     | 61 (95%)     |
| Block    | 10.64.12.64/26    |        64 | 3 (5%)     | 61 (95%)     |
| IP Pool  | 10.64.16.0/20     |      4096 | 9 (0%)     | 4087 (100%)  |
| Block    | 10.64.16.64/26    |        64 | 3 (5%)     | 61 (95%)     |
| Block    | 10.64.17.128/26   |        64 | 3 (5%)     | 61 (95%)     |
| Block    | 10.64.28.64/26    |        64 | 3 (5%)     | 61 (95%)     |
+----------+-------------------+-----------+------------+--------------+
```

## Step 6: Disable an IP pool
You can disable an IP Pool.
```sh
calicoctl patch ippool external-pool -p '{"spec": {"disabled": true}}'
```

Now let's try to start a Pod
```sh
kubectl run nginx --image=nginx -n external-ns
```

It will failr. You will get the following error message from the command: `kubectl describe pods nginx -n external-ns`:
```
the given pool (10.64.0.0/20) does not exist, or is not enabled
```


# Cleanup
## Step 1: Delete the deployments
kubectl delete -f nginx-dp.yaml

## Step 2: Delete the IP Pools
kubectl delete -f pools.yaml

## Step 3: Delete the namespaces (this could replace the commands above)
kubectl delete namespace external-ns
kubectl delete namespace internal-ns

# Reference
[Calico IPAM: Explained and Enhanced](https://www.tigera.io/blog/calico-ipam-explained-and-enhanced/)
