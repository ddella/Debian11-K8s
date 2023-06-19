# New Users in Kubernetes
All Kubernetes clusters have two categories of users: `ServiceAccount` managed by Kubernetes, and `normal users`. Kubernetes does not have objects which represent normal user accounts. Normal users cannot be added to a cluster through an API call. Any user that presents a valid certificate signed by the cluster’s certificate authority (CA) is considered authenticated. So, you need to create a certificate for you username.


## Create a `normal user` account
Create a new Linux user, assign the groups and set the password. This is done on the Kubernetes **control plane** only:
```sh
sudo useradd -s /bin/bash -m -G docker,crictl user1
sudo passwd user1
```

## Create a Certificate Signing Request (CSR)
Create a certificate for that user you created in the step above. I'll create an ECC private key and a Certificate Signing Request (CSR).

>**Note:**At the time of this writing, ECC is not supported. I got the message `x509: unsupported elliptic curve` when trying to have K8s signed the CSR.

Create a private key for `user1`:
```sh
# openssl ecparam -name secp256k1 -genkey -out user1-key.pem
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out user1-key.pem
```

Create a Certificate Signing Request (CSR). It is important that you assign a Subject with the name of the user and the namespace which you plan to use for `user1`. The user needs to make sure he:

- Use his name in the Common Name (CN) field: this will be used to identify him against the API Server.
- Use the group name in the Organisation (O) field: this will be used to identify the group against the API Server.

This is the command to generate the CSR:
```sh
openssl req -new -sha256 -key user1-key.pem -subj "/C=CA/ST=QC/L=Montreal/CN=user1/O=user1-ns" \
-addext "basicConstraints = CA:FALSE" \
-addext "extendedKeyUsage = clientAuth" \
-addext "subjectKeyIdentifier = hash" \
-addext "keyUsage = nonRepudiation, digitalSignature, keyEncipherment, keyAgreement, dataEncipherment" \
-out user1-csr.pem
```

Once the `user1-csr.pem` file is created, `user1` needs to send it to the admins so it can be signed using the K8s cluster Certificate Authority.

## Signing the certificate
We need the `user1-csr.pem` file to generate a `CertificateSigningRequest` object in Kubernetes. The manifest file looks loke this:
```yaml
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: user1-request
spec:
  groups:
  - system:authenticated
  # the base64 encoded value of the CSR file content
  request: ${BASE64_CSR}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 315360000  # ten years
  usages:
  # usages has to be 'client auth'
  - client auth
```

The value of the `request` key is the content of the file `user1-csr.pem` in base64 without the line feeds.

```sh
cat > user1-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: user1-csr
spec:
  groups:
  - system:authenticated
  request: $(cat ./user1-csr.pem | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 315360000
  usages:
  - client auth
EOF
```
>**Note:** Make sure NOT to surround `EOF` with single quotes, as it will not execute the `base64` command.

Let's create the `CertificateSigninRequest` resource with the command:
```sh
kubectl create -f user1-csr.yaml
```

You should get the following output:
```
certificatesigningrequest.certificates.k8s.io/user1-csr created
```

Check the status of the CSR, don't worry it will be in Pending state.
```sh
kubectl get csr
```

You should get the following output:
```
NAME        AGE   REQUESTOR            CONDITION
user1-csr   9s    28b93...d73801ee46   Pending
```

## Approve the CSR:
Use `kubectl` to approve the CSR:
```sh
kubectl certificate approve user1-csr
```

You should get the following output:
```
certificatesigningrequest.certificates.k8s.io/user1-csr approved
```

## Get the certificate
You can retreive the certificate from the CSR. The certificate value is in Base64-encoded format under `status.certificate`:
```sh
kubectl get csr/user1-csr -o yaml
```

Export the issued certificate from the `CertificateSigningRequest` and save it to a file.
```sh
kubectl get csr user1-csr -o jsonpath='{.status.certificate}'| base64 -d > user1-crt.pem
```

You can view the certificate with the command:
```sh
openssl x509 -in user1-crt.pem -noout -text
```

>Certificate is only valid one year, even if the CRS said otherwise 😉


## Create namespace
We can create a namespace so all the resources `user1` and his team will deploy are isolated from the other workload of the cluster.
```sh
kubectl create namespace user1-ns
```

The output should look like this:
```
namespace/user1-ns created
```

# Setting Up RBAC Rules
By creating a certificate, we allow `user1` to authenticate against the API Server, but we did not specify any rights so the user will not be able to do anything. Let's give our new user the rights to create, get, update, list and delete Deployment and Service resources in his namespace `user1-ns`.

In a nutshell: A `Role` (the same applies to a `ClusterRole`) contains a list of rules. Each rule defines some actions that can be performed (eg: list, get, watch, …) against a list of resources (eg: Pod, Service, Secret) within apiGroups (eg: core, apps/v1, …). While a `Role` defines rights for a specific namespace, the scope of a `ClusterRole` is the entire cluster


## Creation of a Role
Let’s first create a Role resource with the following specification:

```sh
cat > user1-role.yaml <<EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 namespace: user1-ns
 name: dev
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
kubectl create -f user1-role.yaml
```

The output should look like this:
```
role.rbac.authorization.k8s.io/dev created
```

## Creation of a RoleBinding
The purpose of a `RoleBinding` is to link a `Role` (list of authorized actions) and a user or a group. In order for `user1` to have the rights specified in the above `Role`, we need to bind `user1` to this `Role`. We will use the following `RoleBinding` resource for this purpose:

```sh
cat > user1-rolebinding.yaml <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: dev
 namespace: user1-ns
subjects:
# - kind: Group
#   name: dev
- kind: User
  name: user1
  apiGroup: rbac.authorization.k8s.io
roleRef:
 kind: Role
 name: dev
 apiGroup: rbac.authorization.k8s.io
EOF
```

This `RoleBinding` links:
- A subject: our user `user1`.
- A role: the one named `dev` that allows to create/get/update/list/delete the Deployment and Service resources that we defined above.

Note: as our user belongs to the `dev` group, we could have used `kind: Group`, see comments in the `yaml` file above. Remember the group information is provided in the Organisation (O) field within the certificate that is sent with each request.

Create the role with the following command:
```sh
kubectl create -f user1-rolebinding.yaml
```

The output should look like this:
```
rolebinding.rbac.authorization.k8s.io/dev created
```

## Building a Kube Config for `user1`
Everything is set up. We now have to send `user1` the information needed to configure the local `kubectl` client to communicate with our cluster.

```sh
# User identifier
export USER="user1"
# Cluster Name
export CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[].name}')
# Client certificate
export CLIENT_CERTIFICATE_DATA=$(kubectl get csr user1-csr -o jsonpath='{.status.certificate}')
# Cluster Certificate Authority (create file ${CLUSTER_NAME}-ca.pem)
kubectl config view --raw -o jsonpath='{range .clusters[*].cluster}{.certificate-authority-data}' | base64 -d > ${CLUSTER_NAME}-ca.pem
# API Server endpoint
export CLUSTER_ENDPOINT=$(kubectl config view -o jsonpath='{range .clusters[*].cluster}{.server}')
```

Create the K8s configuration file:
```sh
kubectl --kubeconfig ~/.kube/config-${USER} config set-cluster ${CLUSTER_NAME} --server=${CLUSTER_ENDPOINT}
kubectl --kubeconfig ~/.kube/config-${USER} config set-cluster ${CLUSTER_NAME} --embed-certs --certificate-authority=${CLUSTER_NAME}-ca.pem
kubectl --kubeconfig ~/.kube/config-${USER} config set-credentials ${USER} --client-certificate=${USER}-crt.pem --client-key=${USER}-key.pem --embed-certs=true
kubectl --kubeconfig ~/.kube/config-${USER} config set-context default --cluster=${CLUSTER_NAME} --user=${USER}
kubectl --kubeconfig ~/.kube/config-${USER} config use-context default
```

The file `~/.kube/config-${USER}` should look like this template.
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
    client-certificate-data: ${CLIENT_CERTIFICATE_DATA}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    user: ${USER}
  name: ${USER}-${CLUSTER_NAME}
current-context: ${USER}-${CLUSTER_NAME}
```

## Test the new user
Just prepand all the `kubectl` commands with `--kubeconfig ~/.kube/config-${USER}` to use his file instead of your configuration file.

Try to list the Pods in the default namespace with the command:
```sh
kubectl --kubeconfig ~/.kube/config-${USER} get pods
```

The command should fail since we gave `user1` access to the namespace `user1-ns`. The output should look like this:
```
Error from server (Forbidden): pods is forbidden: User "user1" cannot list resource "pods" in API group "" in the namespace "default"
```

Try to list the Pods in the `user1-ns` namespace with the command:
```sh
kubectl --kubeconfig ~/.kube/config-${USER} get pods -n user1-ns
```

This time the command should succeed with the output:
```
No resources found in user1-ns namespace.
```

## Install the file `~/.kube/config-${USER}` for `user1`
We can now send the kubeconfig file `~/.kube/config-${USER}` to user `user1`. Be aware that his private key is inside the file 🔐. Login as `user1` and execute the command below to install the K8s configuration file. Adjust the source directory of the file.

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

Delete user `user1` in K8s with the command:
```sh
kubectl config delete-user ${USER}
```

Delete user `user1` in Linux with the command:
```sh
sudo userdel -f -r ${USER}
```

Unset values shell variables with the commands:
```sh
unset USER
unset CLUSTER_NAME
unset CLIENT_CERTIFICATE_DATA
unset CLUSTER_ENDPOINT
```

Remove all certificates, private key and CSR related to the user with the command:
```sh
rm -f ${USER}*.pem
```

# References
https://betterprogramming.pub/k8s-tips-give-access-to-your-clusterwith-a-client-certificate-dfb3b71a76fe
https://devopstales.github.io/kubernetes/k8s-user-accounts/
