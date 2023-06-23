# To be executed on your jump

# Change the username
export NEWUSER="my username"

# -----------------------------------------------------------------------------
# No modification after this line
# -----------------------------------------------------------------------------
# Sets a random password for the new user
export NEWUSER_PASSWORD=$(openssl rand -base64 8)

# Create a local user
sudo useradd -s /bin/bash -m ${NEWUSER}
sudo chpasswd <<<"${NEWUSER}:${NEWUSER_PASSWORD}"
# Force to change password at next login
sudo passwd --expire ${NEWUSER}

# openssl ecparam -name secp256k1 -genkey -out ${NEWUSER}-key.pem
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out ${NEWUSER}-key.pem

openssl req -new -sha256 -key ${NEWUSER}-key.pem -subj "/C=CA/ST=QC/L=Montreal/CN=${NEWUSER}/O=${NEWUSER}-ns" \
-addext "basicConstraints = CA:FALSE" \
-addext "extendedKeyUsage = clientAuth" \
-addext "subjectKeyIdentifier = hash" \
-addext "keyUsage = digitalSignature, keyEncipherment" \
-out ${NEWUSER}-csr.pem

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

kubectl apply -f ${NEWUSER}-csr.yaml
kubectl certificate approve ${NEWUSER}-csr
kubectl get csr/${NEWUSER}-csr -o yaml
kubectl get csr ${NEWUSER}-csr -o jsonpath='{.status.certificate}'| base64 -d > ${NEWUSER}-crt.pem
openssl x509 -in ${NEWUSER}-crt.pem -noout -text
kubectl create namespace ${NEWUSER}-ns

cat > ${NEWUSER}-role.yaml <<EOF
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
 namespace: ${NEWUSER}-ns
 name: ${NEWUSER}-role
rules:
# An empty string designates the core API group
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["create", "get", "update", "list", "delete"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "get", "update", "list", "delete"]
EOF

kubectl apply -f ${NEWUSER}-role.yaml

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

kubectl apply -f ${NEWUSER}-rolebinding.yaml

# Cluster Name
export CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[].name}')
# Client certificate
export CLIENT_CERTIFICATE=$(kubectl get csr ${NEWUSER}-csr -o jsonpath='{.status.certificate}')
# Cluster Certificate Authority (it creates file ${CLUSTER_NAME}-ca.pem)
kubectl config view --raw -o jsonpath='{range .clusters[*].cluster}{.certificate-authority-data}' | base64 -d > ${CLUSTER_NAME}-ca.pem
# API Server endpoint
export CLUSTER_ENDPOINT=$(kubectl config view -o jsonpath='{range .clusters[*].cluster}{.server}')

kubectl --kubeconfig config-${NEWUSER} config set-cluster ${CLUSTER_NAME} --server=${CLUSTER_ENDPOINT}
kubectl --kubeconfig config-${NEWUSER} config set-cluster ${CLUSTER_NAME} --embed-certs --certificate-authority=${CLUSTER_NAME}-ca.pem
kubectl --kubeconfig config-${NEWUSER} config set-credentials ${NEWUSER} --client-certificate=${NEWUSER}-crt.pem --client-key=${NEWUSER}-key.pem --embed-certs=true
kubectl --kubeconfig config-${NEWUSER} config set-context ${NEWUSER}@${CLUSTER_NAME} --namespace=${NEWUSER}-ns --cluster=${CLUSTER_NAME} --user=${NEWUSER}
kubectl --kubeconfig config-${NEWUSER} config use-context ${NEWUSER}@${CLUSTER_NAME}

# Copy the K8s config file to the user directory
sudo mkdir -p /home/${NEWUSER}/.kube
sudo cp -i config-${NEWUSER} /home/${NEWUSER}/.kube/config
sudo chown ${NEWUSER}:${NEWUSER} /home/${NEWUSER}/.kube/config

printf "User: ${NEWUSER} with password: [${NEWUSER_PASSWORD}] has been created\n"

# Unset all varaibles
unset USER
unset USER_PASSWORD
unset CLUSTER_NAME
unset CLIENT_CERTIFICATE
unset CLUSTER_ENDPOINT

