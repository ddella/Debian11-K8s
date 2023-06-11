# Echo Server
## Introduction
I created this manifest to play with a K8s cluster deployed on four nodes with the following configuration:

|Role|FQDN|IP|OS|Kernel|
|----|----|----|----|----|
|Master|k8smaster1.example.com|192.168.13.30|Ubuntu 22.04.2|6.3.6|
|Worker|k8sworker1.example.com|192.168.13.35|Ubuntu 22.04.2|6.3.6|
|Worker|k8sworker2.example.com|192.168.13.36|Ubuntu 22.04.2|6.3.6|
|Worker|k8sworker3.example.com|192.168.13.37|Ubuntu 22.04.2|6.3.6|
|N/A|bgp.example.com|192.168.13.39|Ubuntu 22.04.2|6.3.6|
|N/A|ubuntu.example.com|192.168.13.104|Ubuntu 22.04.2|6.3.6|

>Kernel version will change over time 😉

`bgp.example.com` has a eBGP session with every worker node in the cK8s luster.
`ubuntu.example.com` has **no route** from the K8s cluster.

This created 3 Pods acting as a TCP and UDP echo server and 1 Pod acting as a client. All of the Pods are in namespace `echo-server`. I start two containers inside each Pod. One container listen on TCP/1234 and the other one listen on UDP/5678. I'm using `socat` for the servers. You can change the port number in the manifest file under each Pod.

>**Note:**No Pod on the K8s master node

## Create the manifest
Let Rock'N Rool and create the manifest.

### (Optional) Watch the creation of the Pods, from another terminal
Watch the Pods being created 😀
```sh
kubectl get pods --watch --show-labels
```

### Create the Pods
Creates 3 server Pods and 1 client Pod:
```sh
kubectl create -f echo-server.yaml
```

>**Note:** The `restartPolicy` is set to `Never` so if the cluster is rebooted, the Pods won't start 😉

I decided to get wild and creates five services 😀:
- ClusterIP service `TCP` listening on port `1234`
- LoadBalancer service `TCP` listening on port `32153` with an external IP address of `2.2.2.2`
- NodePort service `TCP` listening on port `31234`
- NodePort service `UDP` listening on port `31678`
- Headless service for DNS resolution

See below the services that were created:
```sh
kubectl get svc -n echo-server
```

The ouput should look like this (IP's will be different for you execpt the external one):
```
NAME              TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
echo-ci-tcp       ClusterIP      10.98.176.251    <none>        1234/TCP         31m
echo-lb-tcp       LoadBalancer   10.100.215.183   2.2.2.2       1234:32153/TCP   31m
echo-np-tcp       NodePort       10.104.117.235   <none>        1234:31234/TCP   31m
echo-server-udp   NodePort       10.107.216.154   <none>        5678:31678/UDP   31m
headless          ClusterIP      None             <none>        <none>           31m
```

## What is does
When the server (container inside a Pod) receives a connection, it replies with:
- the date
- it's IP address and TCP listening port
- the client's IP address and TCP sending port (source of the IP packet)
- and it will echo back everything sent to it

This is an example of what the server sends when it receives a packet:
```
Sun Jun 4 18:37:24 UTC 2023
Server: 10.255.18.158:1234
Client: 10.255.153.116:35953
```

We are using K8s `headless service` to benefit from DNS resolution for each Pod.

Kubernetes headless service is a Kubernetes service that does not assign an IP address to itself. Instead, it returns the IP addresses of the pods associated with it directly to the DNS system, allowing clients to connect to individual pods directly. This means that each pod has its own IP address, making it possible to perform direct communication between the client and the pod.

A headless service exposes **all** the Pods IPs when you do a DNS resolution. Lets try to resolve `headless.echo-server.svc.cluster.local` from the client Pod.

```sh
kubectl exec -it echo-client1 -n echo-server -- nslookup headless.echo-server.svc.cluster.local
```

The ouput should look like this:
```
Server:		10.96.0.10
Address:	10.96.0.10:53

Name:	headless.echo-server.svc.cluster.local
Address: 10.255.153.83
Name:	headless.echo-server.svc.cluster.local
Address: 10.255.18.158
Name:	headless.echo-server.svc.cluster.local
Address: 10.255.77.140
```

## Get the list of Pods
Check that the Pods were created successfuly and that they are running. You should have a Pod on each node for the servers and one client Pod somewhere. Each server Pod will have 2 containers:

```sh
kubectl get pods -n echo-server -o=wide
```

The ouput should look like this:
```
NAME           READY   STATUS    RESTARTS   AGE   IP              NODE                     NOMINATED NODE   READINESS GATES
echo-client1   1/1     Running   0          91m   10.255.77.143   k8sworker1.isociel.com   <none>           <none>
echo-server1   2/2     Running   0          91m   10.255.77.140   k8sworker1.isociel.com   <none>           <none>
echo-server2   2/2     Running   0          91m   10.255.18.158   k8sworker3.isociel.com   <none>           <none>
echo-server3   2/2     Running   0          91m   10.255.153.83   k8sworker2.isociel.com   <none>           <none>
```

# Tests

## From inside the cluster
If you're in a Pod, like the client Pod, you access the echo servers via their name or IP address.

```sh
kubectl exec -it echo-client1 -n echo-server -- /bin/sh
```

>The prompt when you're inside a container should look like this: `/ # `

With the name (you need to add the suffix `.headless`):
```sh
nc server1.headless 1234
Sun Jun 11 16:19:25 UTC 2023
Server: 10.255.77.140:1234
Client: 10.255.77.143:37419

Test1
Test1
```

## From outside the cluster
If you initiate a connection external to the cluster on a client that doesn't have a route to `2.2.2.2`, you need to  use the `NodePort` service with TCP port 31234:

```
daniel@ubuntu ~ $ nc 192.168.13.35 31234
Sun Jun 11 16:21:19 UTC 2023
Server: 10.255.77.140:1234
Client: 192.168.13.104:65363

Testing Worker1
Testing Worker1
^C
---
daniel@ubuntu ~ $ nc 192.168.13.36 31234
Sun Jun 11 16:21:32 UTC 2023
Server: 10.255.153.83:1234
Client: 192.168.13.104:65370

Testing Worker2
Testing Worker2
^C
---
daniel@ubuntu ~ $ nc 192.168.13.37 31234
Sun Jun 11 16:21:43 UTC 2023
Server: 10.255.18.158:1234
Client: 192.168.13.104:65380

Testing Worker3
Testing Worker3
^C
---
daniel@ubuntu ~ $ nc 192.168.13.30 31234
daniel@ubuntu ~ $ 
```

One thing to note here, is that trying the `NodePort` service on the master node fails. This is because I configured the option `externalTrafficPolicy: Local`. That option avoids `SNAT` on the packet from the client. The servers see the real client IP address but for this to work, every node must have the backing Pod.

In the example above, IP `192.168.13.104` is the real IP address of the client.

## From outside the cluster
If you initiate a connection external to the cluster on a client that **has** a route to `2.2.2.2` you can use the `LoadBalancer` service:

```
daniel@bgp ~ $ nc 2.2.2.2 1234
Sun Jun 11 16:55:26 UTC 2023
Server: 10.255.77.140:1234
Client: 192.168.13.39:46952

Testing Worker ???
Testing Worker ???
^C
```

## DNS lookup for headless service
Let's do the DNS lookup from the newly created pod:

```sh
kubectl exec echo-client1 -n echo-server -- nslookup headless.echo-server.svc.cluster.local
```

## Jump inside Pod
If you don't have BGP router, you can jump inside the client Pod and do the tests using the DNS name of the headless service.

```sh
kubectl exec -it echo-client1 -n echo-server -- /bin/sh
```

From inside the Pod, you can try to access any of the server's Pod with it's name or IP address.
The name must have the `.headless` subdomain appended.

To test a TCP connection:

```
nc server1.headless 1234
nc server2.headless 1234
nc server3.headless 1234
```

To test a UDP connection:

```
nc -u server1.headless 5678
nc -u server2.headless 5678
nc -u server3.headless 5678
```

## Cleanup
Delete the namespace, the all the services and all the Pods:
```sh
kubectl delete -f echo-server.yaml
```

# Get some variables
This command returns the `node` name where all the Pods run:
```sh
kubectl get pods -n echo-server -o go-template --template '{{range .items}}{{.spec.nodeName}}{{"\n"}}{{end}}'
```

The ouput should look like this:
```
k8sworker1.isociel.com
k8sworker1.isociel.com
k8sworker3.isociel.com
k8sworker2.isociel.com
```

This command returns the `node` name where a specific Pod runs:
```sh
kubectl get pods echo-server1 -n echo-server -o go-template --template '{{.spec.nodeName}}{{"\n"}}'
```

The ouput should look like this:
```
k8sworker1.isociel.com
```

# BGP
In my lab I activated BGP with [Calico](https://www.tigera.io/project-calico/) and I had a Ubuntu with [FRRouting](https://frrouting.org/), so I could use the `CLUSTER-IP` directly and `Kube Proxy` did the load balancing.
