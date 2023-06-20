# Users access to Kubernetes API
To manage a Kubernetes cluster, `kubectl` is usually used. Behind the hood it calls the API Server: the HTTP Rest API exposing all the endpoints of the cluster’s control plane. When a request is sent to the API Server, it first needs to be authenticated (to make sure the requestor is known by the system) before it’s authorized (to make sure the requestor is allowed to perform the action requested).

The authentication step is done through the use of authentication plugins. There are several plugins as different authentication mechanisms can be used:

- Client certificates (this tutorial)
- Bearer tokens
- Authenticating proxy
- HTTP basic auth

There is no user nor group resources inside a Kubernetes cluster. This should be handled outside of the cluster and provided with each request sent to the API Server.

In this tutorial we'll use Client certificates to authenticate API calls and Role/RoleBinding for authorisation.

## Set the username
Use an environment variable for the user you want to create. It will be used throughout this tutorial:
```sh
# User to be created
export NEW-USER="adm-user1"
```

## Create a Certificate Signing Request (CSR)
Create a certificate for that user you created in the step above. I'll create an ECC private key and a Certificate Signing Request (CSR).

>**Note:**At the time of this writing, ECC was not supported. I got the message `x509: unsupported elliptic curve` when trying to have K8s signed the CSR.

Start by creating a private key for `${NEWUSER}`:
```sh
# openssl ecparam -name secp256k1 -genkey -out ${NEWUSER}-key.pem
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ${NEWUSER}-key.pem
```

Create a Certificate Signing Request (CSR). It is important that you assign a Subject with the name of the user and the namespace which you plan to use for `${NEWUSER}`. The user needs to make sure he:

- Use his name in the Common Name (CN) field: this will be used to identify him against the API Server.
- Use the group name in the Organisation (O) field: this will be used to identify the group against the API Server.

This is the command to generate the CSR:
```sh
openssl req -new -sha256 -key ${NEWUSER}-key.pem -subj "/C=CA/ST=QC/L=Montreal/CN=${NEWUSER}/O=${NEWUSER}-ns" \
-addext "basicConstraints = CA:FALSE" \
-addext "extendedKeyUsage = clientAuth" \
-addext "subjectKeyIdentifier = hash" \
-addext "keyUsage = nonRepudiation, digitalSignature, keyEncipherment, keyAgreement, dataEncipherment" \
-out ${NEWUSER}-csr.pem
```

Once the `${NEWUSER}-csr.pem` file is created, it can be signed using the K8s cluster Certificate Authority.

## Signing the certificate
We need the `${NEWUSER}-csr.pem` file to generate a `CertificateSigningRequest` object in Kubernetes. The value of the `request` key is the content of the file `${NEWUSER}-csr.pem` in base64 without the line feeds.
```sh
cat > ${NEWUSER}-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${NEWUSER}-csr
spec:
  groups:
  - system:authenticated
  request: $(cat ${NEWUSER}-csr.pem | base64 | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 315360000
  usages:
  - digital signature
  - key encipherment
  - client auth
EOF
```
>**Note:** Make sure NOT to surround `EOF` with single quotes, as it will not evaluate any variables or commands.

Let's create the `CertificateSigninRequest` resource with the command:
```sh
kubectl apply -f ${NEWUSER}-csr.yaml
```

You should get the following output:
```
certificatesigningrequest.certificates.k8s.io/${NEWUSER}-csr created
```

Check the status of the CSR, don't worry it will be in Pending state.
```sh
kubectl get csr
```

You should get the following output:
```
NAME            AGE   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
adm-${NEWUSER}-csr   24s   kubernetes.io/kube-apiserver-client   kubernetes-admin   10y                 Pending
```

## Approve the CSR:
Use `kubectl` to approve the CSR:
```sh
kubectl certificate approve ${NEWUSER}-csr
```

You should get the following output:
```
certificatesigningrequest.certificates.k8s.io/${NEWUSER}-csr approved
```

## Get the certificate
(Optional: for information only) You can retrieve the certificate from the CSR. The certificate value is in Base64-encoded format under `status.certificate`:
```sh
kubectl get csr/${NEWUSER}-csr -o yaml
```

Export the issued certificate from the `CertificateSigningRequest` and save it to a file.
```sh
kubectl get csr ${NEWUSER}-csr -o jsonpath='{.status.certificate}'| base64 -d > ${NEWUSER}-crt.pem
```

You can view the certificate with the command:
```sh
openssl x509 -in ${NEWUSER}-crt.pem -noout -text
```

>Certificate is only valid one year, even if the CRS said otherwise 😉

## Create namespace
Create a namespace so all the resources `${NEWUSER}` will deploy are isolated from the other workload of the cluster.
```sh
kubectl create namespace ${NEWUSER}-ns
```

The output should look like this:
```
namespace/${NEWUSER}-ns created
```

# Setting Up RBAC Rules
By creating a certificate, we allow `${NEWUSER}` to authenticate against K8s API Server, but we did not specify any rights so the user will not be able to do anything. Let's give our new user the rights to create, get, update, list and delete Deployment and Service resources in his namespace `${NEWUSER}-ns`.

In a nutshell: A `Role` (the same applies to a `ClusterRole`) contains a list of rules. Each rule defines some actions that can be performed (eg: list, get, watch, …) against a list of resources (eg: Pod, Service, Secret) within apiGroups (eg: core, apps/v1, …). While a `Role` defines rights for a specific namespace, the scope of a `ClusterRole` is the entire cluster

## Creation of a Role
Let’s first create a Role resource with the following specification:

```sh
cat > ${NEWUSER}-role.yaml <<EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 namespace: ${NEWUSER}-ns
 name: ${NEWUSER}-role
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["create", "get", "update", "list", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "get", "update", "list", "delete"]
EOF
```

Below is a table of the API groups and resources `apiGroups`:

|apiGroup|Resources|
|:---|:---|
|apps|daemonsets, deployments, deployments/rollback, deployments/scale, replicasets, replicasets/scale, statefulsets, statefulsets/scale|
|core|configmaps, endpoints, persistentvolumeclaims, replicationcontrollers, replicationcontrollers/scale, secrets, serviceaccounts, services,services/proxy|
|autoscaling|horizontalpodautoscalers|
|batch|cronjobs, jobs|
|policy|poddisruptionbudgets|
|networking.k8s.io|networkpolicies|
|authorization.k8s.io|localsubjectaccessreviews|
|rbac.authorization.k8s.io|rolebindings,roles|
|extensions|deprecated (read notes)|

Pods and Services resources belongs to the core API group (value of the apiGroups key is the empty string), whereas Deployments resources belongs to the apps API group. For those 2 apiGroups, we defined the list of resources and the actions that should be authorized on those ones.

Create the role with the following command:
```sh
kubectl apply -f ${NEWUSER}-role.yaml
```

The output should look like this:
```
role.rbac.authorization.k8s.io/${NEWUSER}-role created
```

## Creation of a RoleBinding
The purpose of a `RoleBinding` is to link a `Role` (list of authorized actions) and a user or a group. In order for `${NEWUSER}` to have the rights specified in the above `Role`, we need to bind `${NEWUSER}` to this `Role`. We will use the following `RoleBinding` resource for this purpose:

```sh
cat > ${NEWUSER}-rolebinding.yaml <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 name: ${NEWUSER}-rolebinding
 namespace: ${NEWUSER}-ns
subjects:
# - kind: Group
#   name: ${NEWUSER}
- kind: User
  name: ${NEWUSER}
  apiGroup: rbac.authorization.k8s.io
roleRef:
 kind: Role
 name: ${NEWUSER}-role
 apiGroup: rbac.authorization.k8s.io
EOF
```

This `RoleBinding` links:
- A subject: our user `${NEWUSER}`.
- A role: the one named `${NEWUSER}-role` that allows to create/get/update/list/delete the Deployment and Service resources that we defined above.

Note: as our user belongs to the `dev` group, we could have used `kind: Group`, see comments in the `yaml` file above. Remember the group information is provided in the Organisation (O) field within the certificate that is sent with each request.

Create the role with the following command:
```sh
kubectl apply -f ${NEWUSER}-rolebinding.yaml
```

The output should look like this:
```
rolebinding.rbac.authorization.k8s.io/${NEWUSER}-rolebinding created
```

## Building a Kube Config for `${NEWUSER}`
The only thing left is to create the K8s configuration file, usualy `~/.kube/config`. This file is needed by `kubectl` client to communicate with the K8s cluster.

```sh
# Cluster Name
export CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[].name}')
# Client certificate
export CLIENT_CERTIFICATE=$(kubectl get csr ${NEWUSER}-csr -o jsonpath='{.status.certificate}')
# Cluster Certificate Authority (it creates file ${CLUSTER_NAME}-ca.pem)
kubectl config view --raw -o jsonpath='{range .clusters[*].cluster}{.certificate-authority-data}' | base64 -d > ${CLUSTER_NAME}-ca.pem
# API Server endpoint
export CLUSTER_ENDPOINT=$(kubectl config view -o jsonpath='{range .clusters[*].cluster}{.server}')
```

List the available contexts:
```sh
kubectl config get-contexts
```

The output should look like this:
```
CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
*         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin   
```

Create the K8s configuration file:
```sh
kubectl --kubeconfig config-${NEWUSER} config set-cluster ${CLUSTER_NAME} --server=${CLUSTER_ENDPOINT}
kubectl --kubeconfig config-${NEWUSER} config set-cluster ${CLUSTER_NAME} --embed-certs --certificate-authority=${CLUSTER_NAME}-ca.pem
kubectl --kubeconfig config-${NEWUSER} config set-credentials ${NEWUSER} --client-certificate=${NEWUSER}-crt.pem --client-key=${NEWUSER}-key.pem --embed-certs=true
kubectl --kubeconfig config-${NEWUSER} config set-context ${NEWUSER}@${CLUSTER_NAME} --namespace=${NEWUSER}-ns --cluster=${CLUSTER_NAME} --user=${NEWUSER}
kubectl --kubeconfig config-${NEWUSER} config use-context ${NEWUSER}@${CLUSTER_NAME}
```

The file `config-${NEWUSER}` should look like this template.
```yaml
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_ENDPOINT}
  name: ${CLUSTER_NAME}
contexts:
- context:
    cluster: ${CLUSTER_NAME}
    namespace: ${NEWUSER}-ns
    user: ${NEWUSER}
  name: ${NEWUSER}@${CLUSTER_NAME}
current-context: ${NEWUSER}1@${CLUSTER_NAME}
kind: Config
preferences: {}
users:
- name: ${NEWUSER}
  user:
    client-certificate-data: ${CLIENT_CERTIFICATE}
    client-key-data: ${NEWUSER}-key.pem
```

## Test the new user
For testing purposes, append all the `kubectl` commands with `--kubeconfig config-${NEWUSER}` to use the K8s configuration file you just created, instead of yours.

>**Note:**Since we configured the ${NEWUSER} with the command `kubectl --kubeconfig config-${NEWUSER} config use-context ${NEWUSER}@${CLUSTER_NAME}`, every command the user enter are in the context of it's namespace.

Try to list the Pods in the `default` namespace with the command:
```sh
kubectl --kubeconfig config-${NEWUSER} get pods
```

This command should succeed because it's run in the context of the namespace `${NEWUSER}-ns`:
```
No resources found in adm-user1-ns namespace.
```

Try to list the Pods in the `default` namespace with the command:
```sh
kubectl --kubeconfig config-${NEWUSER} get pods -n default
```

The command should fail since we gave `${NEWUSER}` access only to the namespace `${NEWUSER}-ns`. The output should look like this:
```
Error from server (Forbidden): pods is forbidden: User "adm-user1" cannot list resource "pods" in API group "" in the namespace "default"
```

## Create a Pod
Just create a standard Nginx Pod with this manifest:
```sh
cat > ${NEWUSER}-pod.yaml <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  namespace: ${NEWUSER}-ns
spec:
  containers:
  - name: nginx-container
    image: nginx
    ports:
    - containerPort: 80
  restartPolicy: Never
EOF
```

Create a Pod with the command:
```sh
kubectl --kubeconfig config-${NEWUSER} create -f ${NEWUSER}-pod.yaml
```

List the Pods in the `${NEWUSER}-ns` namespace with the command (no need to specify the namespace):
```sh
kubectl --kubeconfig config-${NEWUSER} get pods
```

You should see the Pod `nginx-pod`.
```
NAME        READY   STATUS    RESTARTS   AGE
nginx-pod   1/1     Running   0          39s
```

Delete a Pod with the command:
```sh
kubectl --kubeconfig config-${NEWUSER} delete -f ${NEWUSER}-pod.yaml
```

## Install the file `config-${NEWUSER}` for `${NEWUSER}`
We can now send the kubeconfig file `config-${NEWUSER}` to user `${NEWUSER}`. Be aware that his private key is inside the file 🔐. Login as `${NEWUSER}` and execute the command below to install the K8s configuration file. Adjust the source directory of the file.

Execute those commands as normal user ${NEWUSER}:
```sh
mkdir -p $HOME/.kube
cp -i SRC/DIRECTORY/config-${NEWUSER} $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

## Summary
We showed how to use a client certificate to authorize users into a Kubernetes cluster. We could have used other ways to set up this authentication, like external identity provider. Once the authentication was set up, we used a `Role` to define some rights limited to a namespace and bind it to the user with a `RoleBinding`. In case we need to provide Cluster-wide rights, we could use `ClusterRole` and `ClusterRoleBinding` resources.

# Troubleshooting

kubectl api-resources
kubectl explain RoleBinding
kubectl explain Role
kubectl get role -A
kubectl get rolebinding -A -o=wide


```sh
kubectl  describe role ${NEWUSER}-role -n ${NEWUSER}-ns
```

Output should look like this:
```
Name:         adm-user1-role
Labels:       <none>
Annotations:  <none>
PolicyRule:
  Resources         Non-Resource URLs  Resource Names  Verbs
  ---------         -----------------  --------------  -----
  pods              []                 []              [create get update list delete]
  services          []                 []              [create get update list delete]
  deployments.apps  []                 []              [create get update list delete]
```

## Testing Authorization with can-i

`kubectl` provides the `auth can-i` subcommand for quickly querying the API authorization layer. The command uses the `SelfSubjectAccessReview` API to determine if the current user can perform a given action, and works regardless of the authorization mode used.

In its simplest usage, the `can-i` command takes a verb and a resource.
```sh
kubectl --kubeconfig config-${NEWUSER} auth can-i create deployments
yes
kubectl --kubeconfig config-${NEWUSER} auth can-i create deployments -n default
no
```

Here we don't specify the `config` file but rather we impersonate the new user. This time if we don't specify the namespace, we're in the default:
```sh
kubectl auth can-i create deployments --as ${NEWUSER}
no
kubectl auth can-i create deployments --as ${NEWUSER} -n ${NEWUSER}-ns
yes
```

# Cleanup
Let's cleanup everything we created and leave the place clean 🧹

## Deleting Role
Use the following command to delete a role:
```sh
kubectl delete role ${NEWUSER}-role -n ${NEWUSER}-ns
```

The output should look like this:
```
role.rbac.authorization.k8s.io "dev" deleted
```

## Deleting RoleBinding
Use the following command to delete a role binding along with the namespace under which the binding was created:

```sh
kubectl delete rolebinding ${NEWUSER}-rolebinding -n ${NEWUSER}-ns
```

```
rolebinding.rbac.authorization.k8s.io "dev-role-binding" deleted
```

## Delete namespace
Delete the namespace (this should delete ALL resources associated to that namespace including `rolebinding`):
```sh
kubectl delete namespace ${NEWUSER}-ns
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
rm -f ${NEWUSER}*.pem
rm -f ${CLUSTER_NAME}-ca.pem
```

Remove the configuration file `config-${NEWUSER}` withn the command:
```sh
rm -f config-${NEWUSER}
```

# References
The following sites are great reference, unfortunatly none of them works out of the box.

https://betterprogramming.pub/k8s-tips-give-access-to-your-clusterwith-a-client-certificate-dfb3b71a76fe
https://devopstales.github.io/kubernetes/k8s-user-accounts/
https://www.golinuxcloud.com/kubernetes-rbac/
