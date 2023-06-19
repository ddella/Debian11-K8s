# New Users in Kubernetes
All Kubernetes clusters have two categories of users: `ServiceAccount` managed by Kubernetes, and `normal users`. Kubernetes does not have objects which represent normal user accounts. Normal users cannot be added to a cluster through an API call. Any user that presents a valid certificate signed by the cluster’s certificate authority (CA) is considered authenticated. So, you need to create a certificate for your user.

This tutorial is about creating a user that will have access to K8s API but in a specific namespace only. Thta user won't be able to view, delete, create anything outside of it's namespace.

## Set the username
Use an environment variable for the user you want to create. It will be used throughout this tutorial:
```sh
# User to be created
export USER="adm-user1"
```

## Create a Certificate Signing Request (CSR)
Create a certificate for that user you created in the step above. I'll create an ECC private key and a Certificate Signing Request (CSR).

>**Note:**At the time of this writing, ECC was not supported. I got the message `x509: unsupported elliptic curve` when trying to have K8s signed the CSR.

Start by creating a private key for `${USER}`:
```sh
# openssl ecparam -name secp256k1 -genkey -out ${USER}-key.pem
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ${USER}-key.pem
```

Create a Certificate Signing Request (CSR). It is important that you assign a Subject with the name of the user and the namespace which you plan to use for `${USER}`. The user needs to make sure he:

- Use his name in the Common Name (CN) field: this will be used to identify him against the API Server.
- Use the group name in the Organisation (O) field: this will be used to identify the group against the API Server.

This is the command to generate the CSR:
```sh
openssl req -new -sha256 -key ${USER}-key.pem -subj "/C=CA/ST=QC/L=Montreal/CN=${USER}/O=${USER}-ns" \
-addext "basicConstraints = CA:FALSE" \
-addext "extendedKeyUsage = clientAuth" \
-addext "subjectKeyIdentifier = hash" \
-addext "keyUsage = nonRepudiation, digitalSignature, keyEncipherment, keyAgreement, dataEncipherment" \
-out ${USER}-csr.pem
```

Once the `${USER}-csr.pem` file is created, it can be signed using the K8s cluster Certificate Authority.

## Signing the certificate
We need the `${USER}-csr.pem` file to generate a `CertificateSigningRequest` object in Kubernetes. The value of the `request` key is the content of the file `${USER}-csr.pem` in base64 without the line feeds.
```sh
cat > ${USER}-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USER}-csr
spec:
  groups:
  - system:authenticated
  request: $(cat ${USER}-csr.pem | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 315360000
  usages:
  - client auth
EOF
```
>**Note:** Make sure NOT to surround `EOF` with single quotes, as it will not execute the `base64` command.

Let's create the `CertificateSigninRequest` resource with the command:
```sh
kubectl create -f ${USER}-csr.yaml
```

You should get the following output:
```
certificatesigningrequest.certificates.k8s.io/adm-${USER}-csr created
```

Check the status of the CSR, don't worry it will be in Pending state.
```sh
kubectl get csr
```

You should get the following output:
```
NAME            AGE   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
adm-${USER}-csr   24s   kubernetes.io/kube-apiserver-client   kubernetes-admin   10y                 Pending
```

## Approve the CSR:
Use `kubectl` to approve the CSR:
```sh
kubectl certificate approve ${USER}-csr
```

You should get the following output:
```
certificatesigningrequest.certificates.k8s.io/adm-${USER}-csr approved
```

## Get the certificate
(Optional) You can retrieve the certificate from the CSR. The certificate value is in Base64-encoded format under `status.certificate`:
```sh
kubectl get csr/${USER}-csr -o yaml
```

Export the issued certificate from the `CertificateSigningRequest` and save it to a file.
```sh
kubectl get csr ${USER}-csr -o jsonpath='{.status.certificate}'| base64 -d > ${USER}-crt.pem
```

You can view the certificate with the command:
```sh
openssl x509 -in ${USER}-crt.pem -noout -text
```

>Certificate is only valid one year, even if the CRS said otherwise 😉

## Create namespace
We can create a namespace so all the resources `${USER}` and his team will deploy are isolated from the other workload of the cluster.
```sh
kubectl create namespace ${USER}-ns
```

The output should look like this:
```
namespace/${USER}-ns created
```

# Setting Up RBAC Rules
By creating a certificate, we allow `${USER}` to authenticate against K8s API Server, but we did not specify any rights so the user will not be able to do anything. Let's give our new user the rights to create, get, update, list and delete Deployment and Service resources in his namespace `${USER}-ns`.

In a nutshell: A `Role` (the same applies to a `ClusterRole`) contains a list of rules. Each rule defines some actions that can be performed (eg: list, get, watch, …) against a list of resources (eg: Pod, Service, Secret) within apiGroups (eg: core, apps/v1, …). While a `Role` defines rights for a specific namespace, the scope of a `ClusterRole` is the entire cluster

## Creation of a Role
Let’s first create a Role resource with the following specification:

```sh
cat > ${USER}-role.yaml <<EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 namespace: ${USER}-ns
 name: ${USER}-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["create", "get", "update", "list", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "get", "update", "list", "delete"]
EOF
```

Pods and Services resources belongs to the core API group (value of the apiGroups key is the empty string), whereas Deployments resources belongs to the apps API group. For those 2 apiGroups, we defined the list of resources and the actions that should be authorized on those ones.

Create the role with the following command:
```sh
kubectl create -f ${USER}-role.yaml
```

The output should look like this:
```
role.rbac.authorization.k8s.io/${USER}-role created
```

## Creation of a RoleBinding
The purpose of a `RoleBinding` is to link a `Role` (list of authorized actions) and a user or a group. In order for `${USER}` to have the rights specified in the above `Role`, we need to bind `${USER}` to this `Role`. We will use the following `RoleBinding` resource for this purpose:

```sh
cat > ${USER}-rolebinding.yaml <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: ${USER}-rolebinding
 namespace: ${USER}-ns
subjects:
# - kind: Group
#   name: ${USER}
- kind: User
  name: ${USER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
 kind: Role
 name: ${USER}-role
 apiGroup: rbac.authorization.k8s.io
EOF
```

This `RoleBinding` links:
- A subject: our user `${USER}`.
- A role: the one named `${USER}-role` that allows to create/get/update/list/delete the Deployment and Service resources that we defined above.

Note: as our user belongs to the `dev` group, we could have used `kind: Group`, see comments in the `yaml` file above. Remember the group information is provided in the Organisation (O) field within the certificate that is sent with each request.

Create the role with the following command:
```sh
kubectl create -f ${USER}-rolebinding.yaml
```

The output should look like this:
```
rolebinding.rbac.authorization.k8s.io/${USER}-rolebinding created
```

## Building a Kube Config for `${USER}`
Everything is set up. We now have to send `${USER}` the information needed to configure the local `kubectl` client to communicate with our cluster.

```sh
# Cluster Name
export CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[].name}')
# Client certificate
export CLIENT_CERTIFICATE=$(kubectl get csr ${USER}-csr -o jsonpath='{.status.certificate}')
# Cluster Certificate Authority (it creates file ${CLUSTER_NAME}-ca.pem)
kubectl config view --raw -o jsonpath='{range .clusters[*].cluster}{.certificate-authority-data}' | base64 -d > ${CLUSTER_NAME}-ca.pem
# API Server endpoint
export CLUSTER_ENDPOINT=$(kubectl config view -o jsonpath='{range .clusters[*].cluster}{.server}')
```

Create the K8s configuration file:
```sh
kubectl --kubeconfig config-${USER} config set-cluster ${CLUSTER_NAME} --server=${CLUSTER_ENDPOINT}
kubectl --kubeconfig config-${USER} config set-cluster ${CLUSTER_NAME} --embed-certs --certificate-authority=${CLUSTER_NAME}-ca.pem
kubectl --kubeconfig config-${USER} config set-credentials ${USER} --client-certificate=${USER}-crt.pem --client-key=${USER}-key.pem --embed-certs=true
kubectl --kubeconfig config-${USER} config set-context default --cluster=${CLUSTER_NAME} --user=${USER}
kubectl --kubeconfig config-${USER} config use-context default
```

The file `config-${USER}` should look like this template.
```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_ENDPOINT}
  name: ${CLUSTER_NAME}
users:
- name: ${USER}
  user:
    client-certificate-data: ${CLIENT_CERTIFICATE}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${USER}
  name: ${USER}-${CLUSTER_NAME}
current-context: ${USER}-${CLUSTER_NAME}
```

## Test the new user
Just prepand all the `kubectl` commands with `--kubeconfig config-${USER}` to use it's own K8s configuration file instead of your configuration file.

Try to list the Pods in the default namespace with the command:
```sh
kubectl --kubeconfig config-${USER} get pods
```

The command should fail since we gave `${USER}` access only to the namespace `${USER}-ns`. The output should look like this:
```
Error from server (Forbidden): pods is forbidden: User "${USER}" cannot list resource "pods" in API group "" in the namespace "default"
```

Try to list the Pods in the `${USER}-ns` namespace with the command:
```sh
kubectl --kubeconfig config-${USER} get pods -n ${USER}-ns
```

This time the command should succeed with the output:
```
No resources found in kubectl --kubeconfig config-${USER} get pods -n ${USER}-ns-ns namespace.
```

## Install the file `config-${USER}` for `${USER}`
We can now send the kubeconfig file `config-${USER}` to user `${USER}`. Be aware that his private key is inside the file 🔐. Login as `${USER}` and execute the command below to install the K8s configuration file. Adjust the source directory of the file.

Execute those commands as normal user ${USER}:
```sh
mkdir -p $HOME/.kube
cp -i SRC/DIRECTORY/config-${USER} $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

## Summary
We showed how to use a client certificate to authorize users into a Kubernetes cluster. We could have used other ways to set up this authentication, like external identity provider. Once the authentication was set up, we used a `Role` to define some rights limited to a namespace and bind it to the user with a `RoleBinding`. In case we need to provide Cluster-wide rights, we could use `ClusterRole` and `ClusterRoleBinding` resources.

## Cleanup
Let's cleanup everything we created and leave the place clean 🧹

Delete the namespace (this should delete ALL resources associated to that namespace including `rolebinding`):
```sh
kubectl delete namespace ${USER}-ns
```

Delete user `${USER}` from the configuration file with the command:
```sh
kubectl --kubeconfig config-${USER} config delete-user ${USER}
```

Unset values shell variables with the commands:
```sh
unset USER
unset CLUSTER_NAME
unset CLIENT_CERTIFICATE
unset CLUSTER_ENDPOINT
```

Remove all certificates, private key and CSR related to the user with the command:
```sh
rm -f ${USER}*.pem
rm -f ${CLUSTER_NAME}-ca.pem
```

Remove the configuration file `config-${USER}` withn the command:
```sh
rm -f config-${USER}
```

# References
The following sites are great reference, unfortunatly none of them works out of the box.

https://betterprogramming.pub/k8s-tips-give-access-to-your-clusterwith-a-client-certificate-dfb3b71a76fe
https://devopstales.github.io/kubernetes/k8s-user-accounts/
https://www.golinuxcloud.com/kubernetes-rbac/
