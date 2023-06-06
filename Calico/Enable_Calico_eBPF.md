# Enable Calico eBPF
To enable Calico eBPF we need to:

- Configure Calico so it knows how to connect directly to the API server (rather than relying on kube-proxy to help it connect)
- Disable `kube-proxy`
- Configure Calico to switch to the eBPF dataplane
- Try out DSR mode (Optional) 

## Configure Calico to connect directly to the API server
In eBPF mode, Calico replaces `kube-proxy`. This means that Calico needs to be able to connect directly to the API server (just as `kube-proxy` would normally do). Calico supports a `ConfigMap` to configure these direct connections for all of its components.

>**Note:** It is important the `ConfigMap` points at a stable address for the API server(s) in your cluster. If you have a HA cluster, the `ConfigMap` should point at the load balancer in front of your API servers so that Calico will be able to connect even if one control plane node goes down. In clusters that use DNS load balancing to reach the API server (such as kops and EKS clusters) you should configure Calico to talk to the corresponding domain name.

In our case, we have a single control node hosting the Kubernetes API service. So we will just configure the control node IP address directly:

Use this command to find your K8s API endpoint:
```sh
kubectl cluster-info
```

You should see output that looks like this:
```
Kubernetes control plane is running at https://192.168.13.30:6443
CoreDNS is running at https://192.168.13.30:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

The first line gives you the K8s API endpoint IP address and TCP port number. Lets create the manifest file for the `ConfigMap`.
```sh
cat <<EOF | tee tigera-operator-configMap.yaml > /dev/null
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: kubernetes-services-endpoint
  namespace: tigera-operator
data:
  KUBERNETES_SERVICE_HOST: '192.168.13.30'
  KUBERNETES_SERVICE_PORT: '6443'
EOF
```

Create the `ConfigMap` with the command:
```sh
kubectl create -f tigera-operator-configMap.yaml
```

You should see output that looks like this:
```
configmap/kubernetes-services-endpoint created
```

ConfigMaps can take up to 60s to propagate, wait for 60s and then restart the operator, which itself also depends on this config:
```sh
kubectl delete pod -n tigera-operator -l k8s-app=tigera-operator
```

If you watch the Calico pods, you should see them get recreated with the new configuration:
```sh
watch kubectl get pods -n tigera-operator
```

<!-- Should we also restart the API servers???  NO WE SHOULD NOT
```sh
kubectl delete pod -n calico-apiserver -l k8s-app=calico-apiserver
``` -->

If you watch the Calico API server pods, you should see them get recreated with the new configuration:
```sh
watch kubectl get pods -n calico-apiserver
```

>You can use Ctrl+C to exit from the watch command once all of the Calico pods have come up.

## Disable kube-proxy
Calico’s eBPF native service handling replaces `kube-proxy`. You can free up resources from your cluster by disabling and no longer running kube-proxy. When Calico is switched into eBPF mode it will try to clean up kube-proxy's iptables rules if they are present. 

`kube-proxy` normally runs as a daemonset. So an easy way to stop and remove `kube-proxy` from every node is to add a nodeSelector to that daemonset which excludes all nodes.

Let’s do that now in this cluster by running this command on `k8smaster1`:
```sh
kubectl patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": "true"}}}}}'
```

You should see output that looks like this:
```
daemonset.apps/kube-proxy patched
```

>Then, should you want to start kube-proxy again, you can simply remove the node selector.

## Activate eBPF mode
To enable eBPF mode, change the `spec.calicoNetwork.linuxDataplane` parameter in the operator's installation resource to "BPF"; you must also clear the hostPorts setting because host ports are not supported in BPF mode:

```sh
kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"BPF", "hostPorts":null}}}'
```

You should see output that looks like this:
```
installation.operator.tigera.io/default patched
```

***Please*** be patient. Check the `calico-node-xxxxx` restart with the command:
```sh
watch kubectl get pods -n calico-system
```
>You can use Ctrl+C to exit from the watch command once all of the Calico pods have come up.

## Try out DSR mode

Direct return mode skips a hop through the network for traffic to services (such as node ports) from outside the cluster. This reduces latency and CPU overhead but it requires the underlying network to allow nodes to send traffic with each other's IPs. In AWS, this requires all your nodes to be in the same subnet and for the source/dest check to be disabled.

DSR mode is disabled by default; to enable it, set the `BPFExternalServiceMode` Felix configuration parameter to "DSR". This can be done with `calicoctl`:

```sh
calicoctl patch felixconfiguration default --patch='{"spec": {"bpfExternalServiceMode": "DSR"}}'
```

To switch back to tunneled mode, set the configuration parameter to "Tunnel":
```sh
calicoctl patch felixconfiguration default --patch='{"spec": {"bpfExternalServiceMode": "Tunnel"}}'
```

Switching external traffic mode can disrupt in-progress connections.

# Reversing the process
To revert to standard Linux networking:

1. Since I installed Calico with the operator, reverse the changes to the operator's Installation:
```sh
kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"Iptables"}}}'
```

2. If you disabled kube-proxy, re-enable it (for example, by removing the node selector added above).
```sh
kubectl patch ds -n kube-system kube-proxy --type merge -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": null}}}}}'
```

3. Delete the `ConfigMap` with the command:
```sh
kubectl delete -f tigera-operator-configMap.yaml
```

> Since disabling eBPF mode is disruptive to existing connections, monitor existing workloads to make sure they re-establish any connections that were disrupted by the switch.

# Reference
[Enabling Calico eBPF](https://docs.tigera.io/calico/latest/operations/ebpf/enabling-ebpf)
