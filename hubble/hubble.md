# Setting up Hubble Observability
Hubble is the observability layer of Cilium and can be used to obtain cluster-wide visibility into the network and security layer of your Kubernetes cluster.
Hubble is able to provide visibility at the node level, cluster level or even across clusters in a Multi-Cluster (Cluster Mesh) scenario.

## Helm Repo
If you don't have `helm` installed, follow this tutorial ![helm](helm.md) and don't forget to come back 😀

Setup Cilium Helm repository:
```sh
helm repo add cilium https://helm.cilium.io/
```

## Check the status
Run Cilium status and validate that Cilium is up and running. We're looking for `Cilium` and `Operator` to be OK.
```sh
cilium status
```

The result should look like this:

       /¯¯\
    /¯¯\__/¯¯\    Cilium:          OK
    \__/¯¯\__/    Operator:        OK
    /¯¯\__/¯¯\    Hubble Relay:    disabled
    \__/¯¯\__/    ClusterMesh:     disabled
       \__/

   DaemonSet         cilium             Desired: 4, Ready: 4/4, Available: 4/4
   Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
   Containers:       cilium             Running: 4
                     cilium-operator    Running: 1
   Cluster Pods:     2/2 managed by Cilium
   Image versions    cilium             quay.io/cilium/cilium:v1.13.2@sha256:85708b11d45647c35b9288e0de0706d24a5ce8a378166cadc700f756cc1a38d6: 4
                     cilium-operator    quay.io/cilium/operator-generic:v1.13.2@sha256:a1982c0a22297aaac3563e428c330e17668305a41865a842dec53d241c5490ab: 1

## Run Cilium test
Run the following command to validate that your cluster has proper network connectivity:

```sh
cilium connectivity test
```
>This will take some time.

## Enable Hubble in Cilium
Enable Hubble with UI
```sh
cilium hubble enable --ui
```
>**Note:** If you don't specify `--ui` now and you try later, you'll get an error message. Just do `cilium hubble disable` and do `cilium hubble enable --ui`.

The result should look like this:

  🔑 Found CA in secret cilium-ca
  ℹ️  helm template --namespace kube-system cilium cilium/cilium --version 1.13.2 --set cluster.id=0,cluster.name=kubernetes,encryption.nodeEncryption=false,hubble.enabled=true,hubble.relay.enabled=true,hubble.ui.enabled=true,kubeProxyReplacement=disabled,operator.replicas=1,serviceAccounts.cilium.name=cilium,serviceAccounts.operator.name=cilium-operator,tls.ca.cert=LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUNFekNDQWJxZ0F3SUJBZ0lVSi9kNlA1V2tmNzZKMVNKSWxOdWdOMzRwajMwd0NnWUlLb1pJemowRUF3SXcKYURFTE1Ba0dBMVVFQmhNQ1ZWTXhGakFVQmdOVkJBZ1REVk5oYmlCR2NtRnVZMmx6WTI4eEN6QUpCZ05WQkFjVApBa05CTVE4d0RRWURWUVFLRXdaRGFXeHBkVzB4RHpBTkJnTlZCQXNUQmtOcGJHbDFiVEVTTUJBR0ExVUVBeE1KClEybHNhWFZ0SUVOQk1CNFhEVEl6TURVd016SXdNVFl3TUZvWERUSTRNRFV3TVRJd01UWXdNRm93YURFTE1Ba0cKQTFVRUJoTUNWVk14RmpBVUJnTlZCQWdURFZOaGJpQkdjbUZ1WTJselkyOHhDekFKQmdOVkJBY1RBa05CTVE4dwpEUVlEVlFRS0V3WkRhV3hwZFcweER6QU5CZ05WQkFzVEJrTnBiR2wxYlRFU01CQUdBMVVFQXhNSlEybHNhWFZ0CklFTkJNRmt3RXdZSEtvWkl6ajBDQVFZSUtvWkl6ajBEQVFjRFFnQUVDTmxVdXN6R3RnNFBFVjl5Ti93UVY4eUcKWHJtemhRRlJEeVdwc2Y0b3BadXQ5ZUpHMUMxZzRiZHNSYW9sNXA0NFlLVWdqckg3aVZNZDJpMVdTZTBPbmFOQwpNRUF3RGdZRFZSMFBBUUgvQkFRREFnRUdNQThHQTFVZEV3RUIvd1FGTUFNQkFmOHdIUVlEVlIwT0JCWUVGS3VzCno1SWRSSkpjbTl3UUF1S2tLbzhwWGZWZ01Bb0dDQ3FHU000OUJBTUNBMGNBTUVRQ0lGY3JKaDd4S0hZZmN1ME8KRCswNzRUMXEzMDMrMzNhdWVQQVhpR3UzcGNBcUFpQVRGQlNkd1N0WmgvOUVONDdiQjJQVDJkM3Axb3VlRDF0MApHalg1bm9Vc2xRPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=,tls.ca.key=[--- REDACTED WHEN PRINTING TO TERMINAL (USE --redact-helm-certificate-keys=false TO PRINT) ---],tunnel=vxlan
  ✨ Patching ConfigMap cilium-config to enable Hubble...
  🚀 Creating ConfigMap for Cilium version 1.13.2...
  ♻️  Restarted Cilium pods
  ⌛ Waiting for Cilium to become ready before deploying other Hubble component(s)...
  🚀 Creating Peer Service...
  ✨ Generating certificates...
  🔑 Generating certificates for Relay...
  ✨ Deploying Relay...
  ✨ Deploying Hubble UI and Hubble UI Backend...
  ⌛ Waiting for Hubble to be installed...
  ℹ️  Storing helm values file in kube-system/cilium-cli-helm-values Secret
  ✅ Hubble was successfully enabled!

Enabling Hubble requires port `TCP/4244` to be open on all nodes running Cilium. This is required for `Cilium Relay` to operate correctly.

## Install Hubble Client
In order to access the observability data collected by Hubble, install the Hubble CLI:
```sh
export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
HUBBLE_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then HUBBLE_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-${HUBBLE_ARCH}.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-${HUBBLE_ARCH}.tar.gz /usr/local/bin
rm hubble-linux-${HUBBLE_ARCH}.tar.gz{,.sha256sum}
```

## Validate Hubble API Access
In order to access the Hubble API, create a port forward to the Hubble service from your local machine. This will allow you to connect the Hubble client to the local port 4245 and access the Hubble Relay service in your Kubernetes cluster. For more information on this method, see Use Port Forwarding to Access Application in a Cluster.

In a different terminal, do port forward to hubble-relay:
```sh
kubectl port-forward -n kube-system deployment/hubble-relay 54245:4245
```

Results:  

    Forwarding from 0.0.0.0:4245 -> 4245
    Forwarding from [::]:4245 -> 4245

>Hit Ctrl-C to terminate, this was not permanent.

Now you can validate that you can access the Hubble API via the installed CLI:

```sh
hubble --server localhost:54245 status
```

Results:

    Handling connection for 54245

You can also query the flow API and look for flows:
```sh
hubble --server localhost:54245 observe
```

## Open the Hubble UI
Usually you will never access the UI directly from a K8s node. I made a simple `yaml` file to expose a port on each node (K8s nodePort). You can access the UI with a browser pointing to the K8s worker node IP address.

Create a `hubble-ui.yaml`file:

```yaml
# hubble-ui.yaml
# It will expose node port permanently.
# http://<Kubernetes node IP>:30012

apiVersion: v1
kind: Service
metadata:
  name: hubble-ui
  namespace: kube-system
spec:
  type: NodePort
  selector:
    k8s-app: hubble-ui # label of the Deployment
  ports:
    - name: hubble-ui
      protocol: TCP
      port: 12000        # port exposed internally in the cluster
      targetPort: 8081   # the container port to send requests to
      nodePort: 30012    # port assigned on each the node for external access
```

Now it's time to activate this `nodePort` to be able to access the Hubble UI.
```sh
kubectl apply -f hubble-ui.yaml
```

Point your browser to `http://<node IP>:30012`

>If you want to remove the service, use this command:
```sh
 kubectl delete -f hubble-ui.yaml
 ```

# Troubleshoot
I ran into some issues, nothing serious, but I decided to make a troubleshooting section.

An initial overview of Cilium can be retrieved by listing all pods to verify whether all pods have the status `Running`:

```sh
kubectl -n kube-system get pods -l k8s-app=cilium
```

The result should look like this:

    NAME           READY     STATUS    RESTARTS   AGE
    cilium-2hq5z   1/1       Running   0          4d
    cilium-6kbtz   1/1       Running   0          4d
    cilium-klj4b   1/1       Running   0          4d
    cilium-zmjj9   1/1       Running   0          4d

## Check the Hubble Relay Deployment:
```sh
kubectl describe -n kube-system deployment/hubble-relay
```

## Edit the configmap:
Proceed with Caution, changing advanced configuration preferences can impact Cilium performance or security.

If you don't know what your doing, stay away from this 😀
```sh
kubectl edit configmap cilium-config -n kube-system
```

# Reference
https://docs.cilium.io/en/v1.13/gettingstarted/hubble_setup/#hubble-setup
https://medium.com/@norlin.t/build-a-managed-kubernetes-cluster-from-scratch-part-4-3856f0756a03
Troubleshooting
https://fossies.org/linux/cilium/Documentation/operations/troubleshooting.rst

<a name="docker-ce"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>
