# Adding a Name to the Kubernetes API Server Certificate
In this tutorial, we'll learn how to change a Kubernetes TLS certificate used by the Kubernetes API server. The process of changing the certificate could find use for a few different scenarios like:
- adding a load balancer in front of the control plane
- using a new or different URL/hostname used to access the API server
- enabling the use of SSH tunneling to access the control plane endpoint (add `127.0.0.1` as a SAN to the certificate)

In this scenario I assume that both situations took place after the cluster was bootstrapped with `kubeadm`.

## Background
Before getting into the details of how to update the certificate, I’d like to first provide a bit of background on why this is important.

The Kubernetes API server uses TLS certificates
- to encrypt traffic to/from the API server
- and to authenticate connections to the API server

As such, if you try to connect to the API server using a command-line client like `kubectl` and you use a hostname or IP address that isn’t included in the certificate’s Subject Alternative Names (SANs), you’ll get an error indicating that the certificate isn’t valid for the specified IP address or hostname.

## Get the actual API Server certificate
For this section, you need to be on the master node. You can do it remotly with the command and replace `<master>` with either the DNS name or IP address:
```sh
openssl s_client -showcerts -connect <master>:6443 2>/dev/null </dev/null |  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' | openssl x509 - -text -noout
```

Get the SAN of the actual certificate:
```sh
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -ext subjectAltName
```

Output:
```
X509v3 Subject Alternative Name: 
    DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, DNS:s666dan4051, IP Address:10.96.0.1, IP Address:10.250.12.180
```

```sh
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -subject
```

Output:
```
subject=CN = kube-apiserver
```

```sh
openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -issuer
```

Output:
```
issuer=CN = kubernetes
```

## Updating the API Server’s Certificate
Because the cluster was bootstrapped using `kubeadm`, you can use `kubeadm` to update the API server’s certificate.

To do this, you’ll first need the `kubeadm` configuration file. `kubeadm` writes its configuration into a `ConfigMap` named “kubeadm-config” found in the “kube-system” namespace.

To pull the kubeadm configuration from the cluster into an external file, run this command:
```sh
kubectl -n kube-system get configmap kubeadm-config -o jsonpath='{.data.ClusterConfiguration}' > kubeadm.yaml
```

This creates a file named `kubeadm.yaml`, that looks something like this (your milage may vary):
```
apiServer:
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: v1.27.2
networking:
  dnsDomain: cluster.local
  podSubnet: 10.255.0.0/16
  serviceSubnet: 10.96.0.0/12
scheduler: {}
```

In this particular example, no additional SANs are listed (execpt the standard one). To add at least one SAN, add a `certSANs` list under the `apiServer` section.

Here’s an example (here I’m showing only the apiServer section):

```
apiServer:
  certSANs:
  - "10.96.1.2"
  - "apiserver.domain.com"
  - "apiserver.domain.net"
  extraArgs:
    authorization-mode: Node,RBAC
  timeoutForControlPlane: 4m0s
```

## Create the certificate and new key
>Note: **Needs to be executed on the master node**  

First, move the existing API server certificate and key to another directory. If `kubeadm` sees that they already exist in the designated location, it won’t create new ones:
```sh
sudo mkdir /etc/kubernetes/pki/apiserver
sudo mv /etc/kubernetes/pki/apiserver.{crt,key} /etc/kubernetes/pki/apiserver/.
```

Then, use `kubeadm` to just generate a new certificate. You need `sudo` because `kubeadm` needs to read the CA certificate and key:
```sh
sudo kubeadm init phase certs apiserver --config kubeadm.yaml
```

Output:
```
[certs] Generating "apiserver" certificate and key
[certs] apiserver serving cert is signed for DNS names [apiserver.example.com kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local s666dan4051] and IPs [10.96.0.1 10.250.12.180 10.97.38.197]
```

## Restart API server
The final step is restarting the API server to pick up the new certificate. I just delete the API server Pod. K8s will create a new one for me. Isn't that the beauty of Kubernetes 😀
```sh
kubectl delete $(kubectl get pods -n kube-system -l component=kube-apiserver -o name) -n kube-system
pod "kube-apiserver-s700sml4051" deleted
```

## Verifying the Change
One way to verify the change is to use `openssl` and connect to the load balancer IP address and extract the certificate.
```sh
openssl s_client -showcerts -connect 10.97.38.197:6443 2>/dev/null </dev/null |  sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' | openssl x509 - -text -noout
```

If and **ONLY** if it succeeded, you can proceed to the next sections. If you encounter any problems **DO NOT** continue and fix the issue.

## Updating the In-Cluster Configuration
>Note: **Needs to be executed on the master node**  

The final step is to update the `kubeadm` ConfigMap stored in the cluster. This is important so that when you use `kubeadm` to orchestrate a cluster upgrade later, the updated information will be present in the cluster. Thankfully, this is pretty straightforward:

```sh
sudo kubeadm init phase upload-config kubeadm --config=kubeadm.yaml
```

Output:
```
[upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
```

You can verify the changes to the configuration were applied successfully with this command:
```sh
kubectl -n kube-system get configmap kubeadm-config -o yaml
```

You should see the modification you did for the SAN.

# References
[Adding a Name to the Kubernetes API Server Certificate](https://blog.scottlowe.org/2019/07/30/adding-a-name-to-kubernetes-api-server-certificate/)  
