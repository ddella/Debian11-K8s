# Echo Server
This created 3 Pods acting as a TCP and UDP echo server and 1 Pod acting as a client. The default behavior for the server Pods are to listen on TCP/1234 and UDP/5678 with 2 containers per Pod. You can change the port number in the manifest file under each Pod.

When the server receives a connection, it sends:
- the date
- it's IP address and TCP listening port
- the client's IP address and TCP sending port
- and it will echo back everything sent to it

    Sun Jun 4 18:37:24 UTC 2023
    Server: 10.255.18.158:1234
    Client: 10.255.153.116:35953

We are using K8s `headless service` to benefit from DNS resolution for each Pod.

Kubernetes headless service is a Kubernetes service that does not assign an IP address to itself. Instead, it returns the IP addresses of the pods associated with it directly to the DNS system, allowing clients to connect to individual pods directly. This means that each pod has its own IP address, making it possible to perform direct communication between the client and the pod.

A headless service exposes the actual POD IPs when you try to do a DNS resolution.

## From inside the cluster
If you're in a Pod, like the client Pod, you access the servers via their name or IP address.

```sh
kubectl exec -it echo-client1 -n echo-server -- /bin/sh
```

>The prompt should look like this: `/ # `

With the name (you need to add the suffix `.headless`):
```sh
nc server1.headless 1234
Sun Jun 4 20:34:48 UTC 2023
Server: 10.255.153.121:1234
Client: 10.255.153.122:34177

Test1
Test1
```

## From outside the cluster
Use the `NodePort` service. Hit any `node` name or IP address:

With the name (you need to add the suffix `.headless`):
```sh
nc 192.168.13.37 31234
Sun Jun 4 20:30:16 UTC 2023
Server: 10.255.77.162:1234
Client: 192.168.13.37:52281

Test1
Test1
```
## (Optional) Watch the creation of the Pods, from another terminal
Watch the Pods being created 😀

    kubectl get pods --watch --show-labels

## Create the Pods
Creates 3 server Pods and 1 client Pod

    kubectl create -f echo-server.yaml

## Get the list of Pods
Check that the Pods were created successfuly and that they are running. You should have a Pod on each node for the servers and one client Pod somewhere. Each server Pod will have 2 containers:

    kubectl get pods -n echo-server -o=wide

## Check the service
After creating the service, we can inspect it. We see it has no cluster IP and its endpoints include the pods matching its pod selector.

    kubectl get svc -n echo-server

## DNS lookup for headless service
Let's do the DNS lookup from the newly created pod:

    kubectl exec echo-client1 -n echo-server -- nslookup headless.echo-server.svc.cluster.local

## Jump inside Pod
Jump inside the client Pod.

    kubectl exec -it echo-client1 -n echo-server -- /bin/sh

From inside the Pod, you can try to access any of the server's Pod with it's name or IP address.
The name must have the `.headless` subdomain appended.

To test a TCP connection:

    nc server1.headless 1234
    nc server2.headless 1234
    nc server3.headless 1234

To test a UDP connection:

    nc -u server1.headless 5678
    nc -u server2.headless 5678
    nc -u server3.headless 5678

## Cleanup
Delete the namespace, the headless service and all the Pods:

    kubectl delete -f echo-server.yaml
