<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a name="readme-top"></a>

# Build an AWS EKS Cluster
This tutorial shows how to build a simplem AWS EKS Cluster with Calico for Network Security and eBPF for dataplane.

## Create AWS EKS Cluster
This guide helps you to create all of the required resources to get started with Amazon Elastic Kubernetes Service (Amazon EKS) using `eksctl`, a simple command line utility for creating and managing Kubernetes clusters on Amazon EKS. At the end of this tutorial, you will have a running Amazon EKS cluster that you can deploy applications to. After the cluster has been created, the appropriate kubernetes configuration will be added to your kubeconfig file. This is the file that you have configured in the environment variable `KUBECONFIG` or `~/.kube/config` by default. The use a specific `kubeconfig` file, use the `--kubeconfig` flag with `kubectl`.

EKS allows you to create clusters with alternative Amazon Machine Image (AMI) images. One of these is a purpose-built open source Linux distribution from AWS with a focus on containers running on virtualized or bare-metal hosts. This container focused distribution is called Bottlerocket. A reason to run Bottlerocket is to run with a distribution designed for containers specifically.

In our particular case, Bottlerocket ships with the Linux 5.4 Kernel which supports some of the latest and greatest features, including eBPF. We can create a new cluster with Bottlerocket by specifying the ami-node-family with the eksctl tool.

This will take a while - around 20 minutes, so why not take a break, or read more about [Bottlerocket](https://aws.amazon.com/bottlerocket/):

**Backup** your `~/.kube/config` file, as `eksctl` could update it 😉:
```sh
cp ~/.kube/config ~/.kube/config.eks
```

Check the schema [here](https://eksctl.io/usage/schema/) for more key/value pair:

Use the `yaml file:`
```sh
cat > eks-aws-cni.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: calico-cni
  version: "1.27"
  region: us-east-2
  tags:
    creator: Daniel
    environment: staging
    cni: calico
managedNodeGroups:
  - name: ng1
    amiFamily: Bottlerocket
    instanceType: t3.small
    labels:
      role: worker
    desiredCapacity: 2
    ssh: 
      allow: true
      publicKeyPath: ~/.ssh/id_ed25519_eks.pub
    tags:
      Name: calico-ebpf
vpc:
  publicAccessCidrs: ["96.20.12.121/32"]
  cidr: 10.254.0.0/16
  clusterEndpoints:
    privateAccess: true
    publicAccess: true
  # manageSharedNodeSecurityGroupRules: true
  nat:
    gateway: Single

kubernetesNetworkConfig:
  serviceIPv4CIDR: "10.250.0.0/16"
EOF
```

Create the cluster and a new `KUBECONFIG` file `$HOME/.kube/eks-aws-cni` with the command:
```sh
eksctl create cluster -f eks-aws-cni.yaml --kubeconfig=$HOME/.kube/eks-aws-cni
```
>**Note:**Expect this to take around 20 minutes

The output should look like this:
```
2023-07-01 10:40:12 [ℹ]  eksctl version 0.147.0
2023-07-01 10:40:12 [ℹ]  using region us-east-2
2023-07-01 10:40:13 [ℹ]  setting availability zones to [us-east-2a us-east-2c us-east-2b]
2023-07-01 10:40:13 [ℹ]  subnets for us-east-2a - public:10.254.0.0/19 private:10.254.96.0/19
2023-07-01 10:40:13 [ℹ]  subnets for us-east-2c - public:10.254.32.0/19 private:10.254.128.0/19
2023-07-01 10:40:13 [ℹ]  subnets for us-east-2b - public:10.254.64.0/19 private:10.254.160.0/19
2023-07-01 10:40:13 [ℹ]  nodegroup "ng1" will use "" [Bottlerocket/1.27]
2023-07-01 10:40:13 [ℹ]  using SSH public key "~/.ssh/id_ed25519_eks.pub" as "eksctl-calico-cni-nodegroup-ng1-MpF/9ziDoJz4fbVkkib4baRf/dGMki+zVkBDfAbYCmE" 
2023-07-01 10:40:13 [ℹ]  using Kubernetes version 1.27
2023-07-01 10:40:13 [ℹ]  creating EKS cluster "calico-cni" in "us-east-2" region with managed nodes
2023-07-01 10:40:13 [ℹ]  1 nodegroup (ng1) was included (based on the include/exclude rules)
2023-07-01 10:40:13 [ℹ]  will create a CloudFormation stack for cluster itself and 0 nodegroup stack(s)
2023-07-01 10:40:13 [ℹ]  will create a CloudFormation stack for cluster itself and 1 managed nodegroup stack(s)
2023-07-01 10:40:13 [ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=us-east-2 --cluster=calico-cni'
2023-07-01 10:40:13 [ℹ]  Kubernetes API endpoint access will use provided values {publicAccess=true, privateAccess=true} for cluster "calico-cni" in "us-east-2"
2023-07-01 10:40:13 [ℹ]  CloudWatch logging will not be enabled for cluster "calico-cni" in "us-east-2"
2023-07-01 10:40:13 [ℹ]  you can enable it with 'eksctl utils update-cluster-logging --enable-types={SPECIFY-YOUR-LOG-TYPES-HERE (e.g. all)} --region=us-east-2 --cluster=calico-cni'
2023-07-01 10:40:13 [ℹ]  
2 sequential tasks: { create cluster control plane "calico-cni", 
    2 sequential sub-tasks: { 
        wait for control plane to become ready,
        create managed nodegroup "ng1",
    } 
}
2023-07-01 10:40:13 [ℹ]  building cluster stack "eksctl-calico-cni-cluster"
2023-07-01 10:40:14 [ℹ]  deploying stack "eksctl-calico-cni-cluster"
2023-07-01 10:40:44 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-cluster"
[..]
2023-07-01 10:52:17 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-cluster"
2023-07-01 10:54:20 [ℹ]  building managed nodegroup stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 10:54:20 [ℹ]  deploying stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 10:54:20 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
[..]
2023-07-01 10:57:09 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 10:57:09 [ℹ]  waiting for the control plane to become ready
2023-07-01 10:57:11 [✔]  saved kubeconfig as "$HOME/.kube/eks-aws-cni"
2023-07-01 10:57:11 [ℹ]  no tasks
2023-07-01 10:57:11 [✔]  all EKS cluster resources for "calico-cni" have been created
2023-07-01 10:57:11 [ℹ]  nodegroup "ng1" has 2 node(s)
2023-07-01 10:57:11 [ℹ]  node "ip-10-254-12-188.us-east-2.compute.internal" is ready
2023-07-01 10:57:11 [ℹ]  node "ip-10-254-80-66.us-east-2.compute.internal" is ready
2023-07-01 10:57:11 [ℹ]  waiting for at least 2 node(s) to become ready in "ng1"
2023-07-01 10:57:11 [ℹ]  nodegroup "ng1" has 2 node(s)
2023-07-01 10:57:11 [ℹ]  node "ip-10-254-12-188.us-east-2.compute.internal" is ready
2023-07-01 10:57:11 [ℹ]  node "ip-10-254-80-66.us-east-2.compute.internal" is ready
2023-07-01 10:57:15 [ℹ]  kubectl command should work with "$HOME/.kube/eks-aws-cni", try 'kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get nodes'
2023-07-01 10:57:15 [✔]  EKS cluster "calico-cni" in "us-east-2" region is ready
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Secure the EKS control plane
Secure access to the control plane API with the command below. Replace `<YOUR PUBLIC IP-x>` with your external IP address used to access EKS API. You can add more by separating them with `,`:
```sh
aws eks update-cluster-config --region us-east-2 --name calico-cni \
--resources-vpc-config endpointPublicAccess=true,publicAccessCidrs="<YOUR PUBLIC IP-1>/32",endpointPrivateAccess=true
```

Check the JSON output for the value `errors`, the array should be empty upon success:
```
[...]
"errors": []
[...]
```

## Verify EKS Nodes
Verify that all the requested nodes run on your cluster with the command:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get nodes -o=wide
```

My output looked like this:
```
NAME                                          STATUS   ROLES    AGE     VERSION               INTERNAL-IP     EXTERNAL-IP     OS-IMAGE                                KERNEL-VERSION   CONTAINER-RUNTIME
ip-10-254-12-188.us-east-2.compute.internal   Ready    <none>   5m33s   v1.27.1-eks-61789d8   10.254.12.188   3.139.80.23     Bottlerocket OS 1.14.1 (aws-k8s-1.27)   5.15.108         containerd://1.6.20+bottlerocket
ip-10-254-80-66.us-east-2.compute.internal    Ready    <none>   5m52s   v1.27.1-eks-61789d8   10.254.80.66    18.222.216.26   Bottlerocket OS 1.14.1 (aws-k8s-1.27)   5.15.108         containerd://1.6.20+bottlerocket
```

## Adjust `kubectl` config for AWS EKS
In case you have other K8s cluster that you administer, you can change the Kubernetes configuration in multiple ways, here's two:
- Use an environment variable that points to a specific configuration file:
  - `export KUBECONFIG=$HOME/.kube/eks-aws-cni` (don't forget to change it back or `unset KUBECONFIG`)
- Append the `--kubeconfig=$HOME/.kube/eks-aws-cni` to every `kubectl` command:
  - `kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods`

We will need to set the `KUBECONFIG` environment variable because we can't specify the kubeconfig file with `calicoctl` 😱 Make sure you execute all `calicoctl` command in the same terminal:
```sh
# Keep a copy of the present value
echo ${KUBECONFIG}
export KUBECONFIG=$HOME/.kube/eks-aws-cni
```

>**NOTE:**We don't need to use `--kubeconfig=$HOME/.kube/eks-aws-cni` with `kubectl` since we have set the `KUBECONFIG` environment variable but I kept it to show we're using EKS and not a local K8s cluster.

## SSH to worker node (Optional)
There's almost no reason to SSH in a node but in case, the command should look like this. You need to specify the same key, `~/.ssh/id_ed25519_eks`, that you used in your `yaml` file when we created the cluster:
```sh
ssh -i "~/.ssh/id_ed25519_eks" ec2-user@ec2-18-188-113-117.us-east-2.compute.amazonaws.com
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---------------------------------------------------------

# Deploying YAOBank
YAOBank is a demo application that has 3 different application tiers. It’s a demo application for Kubernetes, useful for testing and learning about Kubernetes networking. The Customer pod connects to the Summary pod, which connects to the Database pod. As such, from the Certified Calico Operator course, you may be familiar with this application.

## Install YAOBank
Download `yaml` the manifest and install it. You could specify the full URL directly with `kubectl -f <url>` but I prefer to keep a local copy a the manifest:
```sh
curl -sLO "https://raw.githubusercontent.com/tigera/ccol2aws/main/yaobank.yaml"
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni create -f yaobank.yaml
```

Example output:
```
namespace/yaobank created
service/database created
serviceaccount/database created
deployment.apps/database created
service/summary created
serviceaccount/summary created
deployment.apps/summary created
service/customer created
serviceaccount/customer created
deployment.apps/customer created
```

We can verify our deployment by looking at the pods in the `yaobank` namespace:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -n yaobank -o=wide
```

Example output:
```
NAME                        READY   STATUS    RESTARTS   AGE    IP              NODE                                          NOMINATED NODE   READINESS GATES
customer-df78b67f9-2rq6n    1/1     Running   0          110s   10.254.23.160   ip-10-254-12-188.us-east-2.compute.internal   <none>           <none>
database-667979bcf6-2kjqf   1/1     Running   0          110s   10.254.27.79    ip-10-254-12-188.us-east-2.compute.internal   <none>           <none>
summary-7b6bb6bb5f-cj2rj    1/1     Running   0          110s   10.254.11.123   ip-10-254-12-188.us-east-2.compute.internal   <none>           <none>
summary-7b6bb6bb5f-lt7x9    1/1     Running   0          110s   10.254.92.8     ip-10-254-80-66.us-east-2.compute.internal    <none>           <none>
```

## Deploy Classic Load Balancer (Optional)
When you create a Kubernetes Service of type `LoadBalancer`, the AWS cloud provider load balancer controller creates AWS **Classic** Load Balancers by default, but can also create AWS Network Load Balancers.

Grab the customer and summary pods’ names and put them in variables for later use:
```sh
export CUSTOMER_POD=$(kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -n yaobank -l app=customer -o name)
export SUMMARY_POD=$(kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -n yaobank -l app=summary -o name | head -n 1)
```

Deploy an ELB to act as the frontend for our customer pod:
```sh
cat > yaobank-elb.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: yaobank-customer-elb
  namespace: yaobank
spec:
  selector:
    app: customer
  ports:
    - port: 80
      targetPort: 80
  type: LoadBalancer
EOF
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni apply -f yaobank-elb.yaml
```

Example output:
```
service/yaobank-customer created
```

```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get svc -n yaobank
```

Example output:
```
NAME               TYPE           CLUSTER-IP       EXTERNAL-IP                                                               PORT(S)        AGE
customer           NodePort       10.250.97.29     <none>                                                                    80:30180/TCP   10m
database           ClusterIP      10.250.174.191   <none>                                                                    2379/TCP       10m
summary            ClusterIP      10.250.48.72     <none>                                                                    80/TCP         10m
yaobank-customer   LoadBalancer   10.250.123.167   a4fcdea5b282e48bf9881633ab1e56eb-1412334652.us-east-2.elb.amazonaws.com   80:30743/TCP   13s
```

From any machine on the Internet, you can access the frontend by connecting to the ELB:
```sh
curl a4fcdea5b282e48bf9881633ab1e56eb-1412334652.us-east-2.elb.amazonaws.com
```

>**NOTE:**The deployment can take up to 5 minutes to be provisioned by AWS (after Kubernetes has provisioned the resource), so feel free to grab a cup of coffee or tea while the load balancer endpoint is provisioned.

Example output:
```
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>YAO Bank</title>
    <style>
    h2 {
      font-family: Arial, Helvetica, sans-serif;
    }
    h1 {
      font-family: Arial, Helvetica, sans-serif;
    }
    p {
      font-family: Arial, Helvetica, sans-serif;
    }
    </style>
  </head>
  <body>
  	<h1>Welcome to YAO Bank</h1>
  	<h2>Name: Spike Curtis</h2>
  	<h2>Balance: 2389.45</h2>
  	<p><a href="/logout">Log Out >></a></p>
  </body>
</html>
```

## Deploy Network Load Balancer
In the preceding section we deployed a classic load balancer, ELB. Now let's deploy a network load balancer, NLB, to act as the frontend for our customer pod. For this you need to install the AWS Load Balancer Controller add-on. See this [tutorial](AWS_Load_Balancer_Controller.md)

```sh
cat > yaobank-nlb.yaml <<EOF
apiVersion: v1
kind: Service
metadata:
  name: yaobank-customer-nlb
  namespace: yaobank
  labels:
    name: yaobank-nlb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  selector:
    app: customer
  ports:
    - port: 80
      targetPort: 80
  type: LoadBalancer
EOF
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni apply -f yaobank-nlb.yaml
```

Example output:
```
service/yaobank-customer-nlb created
```

```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get svc -n yaobank
```

Example output:
```
NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
customer               NodePort       10.250.97.29     <none>                                                                         80:30180/TCP   112m
database               ClusterIP      10.250.174.191   <none>                                                                         2379/TCP       112m
summary                ClusterIP      10.250.48.72     <none>                                                                         80/TCP         112m
yaobank-customer-nlb   LoadBalancer   10.250.210.148   k8s-yaobank-yaobankc-d227132122-647fab65c47649f2.elb.us-east-2.amazonaws.com   80:32311/TCP   11s
```

From any machine on the Internet, you can access the frontend by connecting to the ELB:
```sh
curl http://k8s-yaobank-yaobankc-d227132122-647fab65c47649f2.elb.us-east-2.amazonaws.com
```

>**NOTE:**The deployment can take up to 5 minutes to be provisioned by AWS (after Kubernetes has provisioned the resource), so feel free to grab a cup of coffee or tea while the load balancer endpoint is provisioned.

Example output:
```
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>YAO Bank</title>
    <style>
    h2 {
      font-family: Arial, Helvetica, sans-serif;
    }
    h1 {
      font-family: Arial, Helvetica, sans-serif;
    }
    p {
      font-family: Arial, Helvetica, sans-serif;
    }
    </style>
  </head>
  <body>
  	<h1>Welcome to YAO Bank</h1>
  	<h2>Name: Spike Curtis</h2>
  	<h2>Balance: 2389.45</h2>
  	<p><a href="/logout">Log Out >></a></p>
  </body>
</html>
```

## Logs
Let’s look at the logs. We see the same situation as before with just AWS-CNI. Again, the client IP address is being source NATed, which is undesirable in many cases:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni logs -n yaobank $CUSTOMER_POD
```

Example output:
```
 * Running on http://0.0.0.0:80/ (Press CTRL+C to quit)
10.254.80.66 - - [01/Jul/2023 15:19:22] "GET / HTTP/1.1" 200 -
10.254.12.188 - - [01/Jul/2023 15:28:07] "GET / HTTP/1.1" 200 -
10.254.7.32 - - [01/Jul/2023 17:04:58] "GET / HTTP/1.1" 200 -
10.254.7.32 - - [01/Jul/2023 17:05:46] "GET / HTTP/1.1" 200 -
```

The last two hits came from the NLB.

## Connectivity Test
Now we can exec into the customer pod:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni exec -it $CUSTOMER_POD -n yaobank -c customer -- /bin/bash
```

Next we will connect to the database server from the customer pod, returning all customer information (this command is executed inside the container):
```sh
curl http://database:2379/v2/keys?recursive=true | python -m json.tool
```

If you see a `json` output, it worked. Exit from the Pod:

# Reviewing IP Address Allocation
To confirm this, we will attempt to scale the frontend of yaobank (the customer deployment) to 30 replicas:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni scale -n yaobank --replicas 30 deployments/customer
```

To confirm this behaviour, we will count the pods that are Running in the cluster. If you refresh this command a few times, you will see the number increasing, until it settles down:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -A | grep Running | wc -l
```

Example output for nodes with `T3.small`:
```
22
```

The cluster is unable to provision any more pods. We can validate this by reviewing the pods unable to start - the pending pods:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -A | grep Pending | wc -l
```

Example output for nodes with `T3.small`:
```
19
```

Let's take a closer look at the events for one of the Pending pods. Substitute the name of a pending pod:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni describe pod -n yaobank customer-df78b67f9-4dqvs
```

Example output:
```
Events:
  Type     Reason            Age    From               Message
  ----     ------            ----   ----               -------
  Warning  FailedScheduling  3m33s  default-scheduler  0/2 nodes are available: 2 Too many pods. preemption: 0/2 nodes are available: 2 No preemption victims found for incoming pod..
```

Return the customer deployment to one replica:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni scale -n yaobank --replicas 1 deployments/customer
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

---------------------------------------------------------

# AWS-CNI and Calico for Policy with iptables dataplane
Calico doesn’t have to always operate in CNI mode. Even if you’re using AWS-CNI, you can still secure your cluster using Calico Network Policy. For this we will install Calico for Networkin Policy.

| Policy | IPAM | CNI | Overlay | Routing        | Datastore      |
|--------|------|-----|---------|----------------|----------------|
| Calico | AWS  | AWS | No      | VPN Native     | AWS/Kubernetes |

## Calico for Network Policy
There are multiple ways to install Calico, such as `manifest` and `helm`. However, the recommended method is to install Calico through the `Tigera-Operator`. Based on the operator framework SDK, the operator is just an application dedicated to ensuring your Calico experience is as smooth as possible.

You can install the latest version of the operator by executing the following commands:
```sh
# Get the latest version number of `calico`
VER=$(curl -s https://api.github.com/repos/projectcalico/calico/releases/latest | grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo $VER

# Download Tigera Calico operator:
curl -LO https://raw.githubusercontent.com/projectcalico/calico/v${VER}/manifests/tigera-operator.yaml

# Download Tigera Calico necessary custom resource definitions manifest:
# All manifests: https://github.com/projectcalico/calico/tree/master/manifests
# curl -LO https://raw.githubusercontent.com/projectcalico/calico/v${VER}/manifests/custom-resources.yaml
```

Install the Tigera Calico operator:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni create -f tigera-operator.yaml
```

Example Output:
```
namespace/tigera-operator created
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgpfilters.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/ipreservations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/kubecontrollersconfigurations.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org created
customresourcedefinition.apiextensions.k8s.io/apiservers.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/imagesets.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/installations.operator.tigera.io created
customresourcedefinition.apiextensions.k8s.io/tigerastatuses.operator.tigera.io created
serviceaccount/tigera-operator created
clusterrole.rbac.authorization.k8s.io/tigera-operator created
clusterrolebinding.rbac.authorization.k8s.io/tigera-operator created
deployment.apps/tigera-operator created
```

After a successful deployment, the operator will constantly look for the Calico configuration to set up the CNI and enable its various features depending on your scenario. 
```sh
cat > custom-resources.yaml <<EOF
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  kubernetesProvider: EKS
  cni:
    type: AmazonVPC
  calicoNetwork:
    nodeAddressAutodetectionV4:
      canReach: 1.1.1.1
    bgp: Disabled
---
apiVersion: operator.tigera.io/v1
kind: APIServer 
metadata: 
  name: default 
spec: {}
EOF
```

```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni create -f custom-resources.yaml
```

Example output:
```
installation.operator.tigera.io/default created
apiserver.operator.tigera.io/default created
```

To confirm the successful deployment of Calico, check the "tigerastatus" output:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get tigerastatus
```

Example output (might take up to 30 seconds):
```
NAME        AVAILABLE   PROGRESSING   DEGRADED   SINCE
apiserver   True        False         False      23s
calico      True        False         False      38s
```

Once all the calico pods are running, Calico Network Policy has been deployed (but remember, we’re still using the `AWS-CNI` for connectivity 😀).

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Connectivity Test
We will prove that we can connect to the database server from the customer pod, returning all customer information because we haven’t written a network policy yet:

Now we can exec into the customer pod:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni exec -it $CUSTOMER_POD -n yaobank -c customer -- /bin/bash
```

Next acces the database Pod:
```sh
curl http://database:2379/v2/keys?recursive=true | python -m json.tool
```

Exit the pod and return to cloud shell (terminal):

## Adding a Global Default Deny
As a best practice, a default deny policy within the cluster protects present and future workloads. To implement this, we can use a Calico `GlobalNetworkPolicy`:

```sh
cat > calico-global-policy-default-deny.yaml <<EOF
apiVersion: projectcalico.org/v3
kind: GlobalNetworkPolicy
metadata:
  name: default-app-policy
spec:
  namespaceSelector: has(projectcalico.org/name) && projectcalico.org/name not in {"kube-system", "calico-system","calico-apiserver"}
  types:
  - Ingress
  - Egress
  egress:
    - action: Allow
      protocol: UDP
      destination:
        selector: k8s-app == "kube-dns"
        ports:
          - 53
EOF
```

```sh
calicoctl apply -f calico-global-policy-default-deny.yaml
```

Example output:
```
Successfully applied 1 'GlobalNetworkPolicy' resource(s)
```

Check that Calico Global Network Policy has been applied (Global Network Policy is not namespaced):
```sh
calicoctl get GlobalNetworkPolicy -o wide
```

The output should look like this:
```
NAME                 ORDER   SELECTOR   
default-app-policy   <nil>              
```

Performing the same test on the customer pod results in the traffic being dropped:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni exec -it $CUSTOMER_POD -n yaobank -c customer -- sh -c 'curl --connect-timeout 3 http://database:2379/v2/keys?recursive=true | python -m json.tool'
```

Example output:
```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:03 --:--:--     0
curl: (28) Connection timed out after 3000 milliseconds
No JSON object could be decoded
command terminated with exit code 1
```

Traffic is blocked between the `customer` and `database` Pod, has expected 😀

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Applying Networking Policy
Now that we have confirmed that our default policy has blocked the traffic as expected, we can apply our network policy to permit the intended traffic:

```sh
cat > calico-network-policy-yaobank-permit.yaml <<EOF
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: database-policy
  namespace: yaobank
spec:
  podSelector:
    matchLabels:
      app: database
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: summary
    ports:
      - protocol: TCP
        port: 2379
  egress:
    - to: []
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: customer-policy
  namespace: yaobank
spec:
  podSelector:
    matchLabels:
      app: customer
  ingress:
    - ports:
      - protocol: TCP
        port: 80
  egress:
    - to: []
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: summary-policy
  namespace: yaobank
spec:
  podSelector:
    matchLabels:
      app: summary
  ingress:
    - from:
      - podSelector:
          matchLabels:
            app: customer
      ports:
      - protocol: TCP
        port: 80
  egress:
    - to:
      - podSelector:
          matchLabels:
            app: database
      ports:
      - protocol: TCP
        port: 2379
EOF
```

Create the three (3) Calico Network Policy with the manifest above:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni apply -f calico-network-policy-yaobank-permit.yaml
```

Example output:
```
networkpolicy.networking.k8s.io/database-policy created
networkpolicy.networking.k8s.io/customer-policy created
networkpolicy.networking.k8s.io/summary-policy created
```

Check that Network Policy have been created (Network Policy are namespced):
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get NetworkPolicy --all-namespaces -o wide
```

The output should look like this:
```
NAMESPACE          NAME              POD-SELECTOR     AGE
calico-apiserver   allow-apiserver   apiserver=true   26m
yaobank            customer-policy   app=customer     3m8s
yaobank            database-policy   app=database     3m8s
yaobank            summary-policy    app=summary      3m8s
```

Performing the same test on the customer pod yet again still results in the traffic being dropped (by design, because the customer should not be speaking directly to the database):

```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni exec -it $CUSTOMER_POD -n yaobank -c customer -- sh -c 'curl --connect-timeout 3 http://database:2379/v2/keys?recursive=true | python -m json.tool'
```

Example output:
```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:--  0:00:03 --:--:--     0
curl: (28) Connection timed out after 3000 milliseconds
No JSON object could be decoded
command terminated with exit code 1
```

But, performing the same test on the summary pod (which is intended to be speaking to the database) returns all customer information:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni exec -it $SUMMARY_POD -n yaobank -c summary -- sh -c 'curl --connect-timeout 3 http://database:2379/v2/keys?recursive=true | python -m json.tool'
```

Output will return `JSON` data if it succeeds.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

------------------------------------------------------------------------------------------------------------------------------------------------

# AWS-CNI and Calico for Policy with eBPF dataplane
Now that Calico has been deployed for Networking Policy, we can begin to enable `eBPF` dataplane for our cluster.

The first step we’re going to take is to get the address of the Kubernetes API Server. The `eBPF` dataplane replaces `kube-proxy`. However, in a non-eBPF cluster, Calico uses a service hosted by `kube-proxy` to access the Kubernetes API server. As a result, we need to reconfigure Calico to tell it to talk directly to the Kubernetes API server. It will need equal access to Kubernetes resources that `kube-proxy` has in order to replace that functionality:

## Configure Calico to talk directly to the API server
Let's reconfigure Calico to talk directly to the Kubernetes API server:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get configmap -n kube-system kube-proxy -o jsonpath='{.data.kubeconfig}' | grep server
-- or --
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni cluster-info
```

Example Output:
```
server: https://5f196b8f1e7680cabb59351c5625c35e.sk1.us-east-2.eks.amazonaws.com
```

From this output, we can see that we’re connecting to host `5f196b8f1e7680cabb59351c5625c35e.sk1.us-east-2.eks.amazonaws.com` on port 443 - which is the default port for HTTP TLS traffic. With this in mind, we can create our configuration map that calico-node will read this configuration from.

If you’re following along, you’ll need to replace the value for KUBERNETES_SERVICE_HOST with the one from your own cluster:

```sh
cat > calico-api.yaml<<EOF
kind: ConfigMap
apiVersion: v1
metadata:
  name: kubernetes-services-endpoint
  namespace: tigera-operator
data:
  KUBERNETES_SERVICE_HOST: "5f196b8f1e7680cabb59351c5625c35e.sk1.us-east-2.eks.amazonaws.com"
  KUBERNETES_SERVICE_PORT: "443"
EOF
```

```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni apply -f calico-api.yaml
```

Example output:
```
configmap/kubernetes-services-endpoint created
```

The operator will pick up the change to the config map automatically and do a rolling update of Calico to pass on the change. Confirm that pods restart and then reach the Running state with the following command:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -n calico-system
```

Confirm that the logs for one of your `calico-node`, `calico-typha`, and `tigera-operator` Pods don't contain ERROR.

Logs for `tigera-operator`:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni logs $(kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -n tigera-operator -o name) -n tigera-operator
```

Logs for `calico-node`:
```sh
for i in $(kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -n calico-system -o name -l k8s-app=calico-node)
do
  kubectl --kubeconfig=$HOME/.kube/eks-aws-cni logs $i -c calico-node -n calico-system
done
```

Logs for `calico-typha`:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni logs $(kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -n calico-system -o name -l app.kubernetes.io/name=calico-typha) -n calico-system
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Configure kube-proxy
In eBPF mode Calico replaces kube-proxy so it wastes resources (and reduces performance) to run both. This section explains how to disable kube-proxy in some common environments.

Now that Calico can communicate directly with the eBPF endpoint, we can disable `kube-proxy`. To do this, we can patch `kube-proxy` to use a non-calico node selector. By doing so, we’re telling `kube-proxy` not to run on any nodes (because they’re all running Calico):

```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni patch ds -n kube-system kube-proxy -p '{"spec":{"template":{"spec":{"nodeSelector":{"non-calico": "true"}}}}}'
```

Example output:
```
daemonset.apps/kube-proxy patched
```

>Then, should you want to start kube-proxy again, you can simply remove the node selector.

## Avoiding conflicts with kube-proxy
If you cannot disable `kube-proxy` (for example, because it is managed by your Kubernetes distribution), then you must change Felix configuration parameter `BPFKubeProxyIptablesCleanupEnabled` to false. This can be done with kubectl as follows:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni patch felixconfiguration.p default --patch='{"spec": {"bpfKubeProxyIptablesCleanupEnabled": false}}'
```

Example output:
```
Successfully patched 1 'FelixConfiguration' resource
```

If both `kube-proxy` and `BPFKubeProxyIptablesCleanupEnabled` is enabled then `kube-proxy` will write its iptables rules and Felix will try to clean them up resulting in iptables flapping between the two.

## Enable eBPF mode
To enable eBPF mode, change the `spec.calicoNetwork.linuxDataplane` parameter in the operator's Installation resource to "BPF"; you must also clear the hostPorts setting because host ports are not supported in eBPF mode:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"BPF", "hostPorts":null}}}'
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Test eBPF dataplane
You should have the file `yaobank-nlb.yaml` that we used to create a Network Load Balancer. Let's use it again:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni apply -f yaobank-nlb.yaml
```

Example output:
```
service/yaobank-customer-nlb created
```

```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get svc -n yaobank -l name=yaobank-nlb
```

Example output:
```
NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP                                                                    PORT(S)        AGE
yaobank-customer-nlb   LoadBalancer   10.250.241.158   k8s-yaobank-yaobankc-1a86c7cd9a-849bc127d3e08dff.elb.us-east-2.amazonaws.com   80:32489/TCP   2m42s
```

>**NOTE:**The deployment can take up to 5 minutes to be provisioned by AWS.

From any machine on the Internet, you can access the frontend by connecting to the ELB:
```sh
curl http://k8s-yaobank-yaobankc-1a86c7cd9a-849bc127d3e08dff.elb.us-east-2.amazonaws.com
```

Example output:
```
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>YAO Bank</title>
    <style>
    h2 {
      font-family: Arial, Helvetica, sans-serif;
    }
    h1 {
      font-family: Arial, Helvetica, sans-serif;
    }
    p {
      font-family: Arial, Helvetica, sans-serif;
    }
    </style>
  </head>
  <body>
  	<h1>Welcome to YAO Bank</h1>
  	<h2>Name: Spike Curtis</h2>
  	<h2>Balance: 2389.45</h2>
  	<p><a href="/logout">Log Out >></a></p>
  </body>
</html>
```

## Logs **** FAILED ****
Let’s look at the logs. We see the same situation as before with just AWS-CNI. Again, the client IP address is being source NATed, which was **NOT EXPECTED**:
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni logs -n yaobank $(kubectl --kubeconfig=$HOME/.kube/eks-aws-cni get pods -n yaobank -l app=customer -o name)
```

Example output:
```
 * Running on http://0.0.0.0:80/ (Press CTRL+C to quit)
[...]
10.254.77.59 - - [01/Jul/2023 19:46:30] "GET / HTTP/1.1" 200 -
10.254.77.59 - - [01/Jul/2023 19:46:39] "GET / HTTP/1.1" 200 -
10.254.77.59 - - [01/Jul/2023 19:46:51] "GET / HTTP/1.1" 200 -
10.254.77.59 - - [01/Jul/2023 19:47:04] "GET / HTTP/1.1" 200 -
```

# Lab Cleanup
To clean up the lab, we can use the `eksctl` provisioner to remove the cluster. This should also delete the Elastic Load Balancer we provisioned previously, but you should delete it first, to be sure:

## Delete the Network Load Balancer
```sh
kubectl --kubeconfig=$HOME/.kube/eks-aws-cni delete -f yaobank-nlb.yaml
```

## Delete the EKS Cluster
```sh
eksctl delete cluster --name calico-cni --region us-east-2
```

Example output:
```
2023-07-01 16:13:02 [ℹ]  deleting EKS cluster "calico-cni"
2023-07-01 16:13:03 [ℹ]  will drain 0 unmanaged nodegroup(s) in cluster "calico-cni"
2023-07-01 16:13:03 [ℹ]  starting parallel draining, max in-flight of 1
2023-07-01 16:13:04 [ℹ]  deleted 0 Fargate profile(s)
2023-07-01 16:13:05 [✔]  kubeconfig has been updated
2023-07-01 16:13:05 [ℹ]  cleaning up AWS load balancers created by Kubernetes objects of Kind Service or Ingress
2023-07-01 16:13:09 [ℹ]  
3 sequential tasks: { delete nodegroup "ng1", 
    2 sequential sub-tasks: { 
        2 sequential sub-tasks: { 
            delete IAM role for serviceaccount "kube-system/aws-load-balancer-controller",
            delete serviceaccount "kube-system/aws-load-balancer-controller",
        },
        delete IAM OIDC provider,
    }, delete cluster control plane "calico-cni" [async] 
}
2023-07-01 16:13:09 [ℹ]  will delete stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:13:09 [ℹ]  waiting for stack "eksctl-calico-cni-nodegroup-ng1" to get deleted
2023-07-01 16:13:09 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:13:40 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:14:12 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:15:44 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:16:25 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:18:06 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:19:17 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:20:40 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:22:36 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:24:20 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-nodegroup-ng1"
2023-07-01 16:24:21 [ℹ]  will delete stack "eksctl-calico-cni-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2023-07-01 16:24:21 [ℹ]  waiting for stack "eksctl-calico-cni-addon-iamserviceaccount-kube-system-aws-load-balancer-controller" to get deleted
2023-07-01 16:24:21 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2023-07-01 16:24:51 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2023-07-01 16:24:51 [ℹ]  deleted serviceaccount "kube-system/aws-load-balancer-controller"
2023-07-01 16:24:52 [ℹ]  will delete stack "eksctl-calico-cni-cluster"
2023-07-01 16:24:52 [✔]  all cluster resources were deleted
```

## Delete kubeconfig file
You can delete the file `$HOME/.kube/eks-aws-cni` and unset the variable `KUBECONFIG`:
```sh
unset KUBECONFIG
rm -f $HOME/.kube/eks-aws-cni
```

# Reference
[EKS installation](https://github.com/weaveworks/eksctl/blob/main/README.md#installation)  
[Amazon Elastic Kubernetes Service (EKS)](https://docs.tigera.io/calico/latest/getting-started/kubernetes/managed-public-cloud/eks)  
[AWS EKS Tutorial | What is EKS? | EKS Explained | KodeKloud](https://www.youtube.com/watch?v=CukYk43agA4)
[eksctl shcema](https://eksctl.io/usage/schema/)  
[Tigera Calico on the AWS Cloud Quick Start Reference Deployment](https://aws-quickstart.github.io/quickstart-eks-tigera-calico/)  
Without the following tutorial, I was unable to make Calico work:  
[Installing the Calico network policy engine add-on](https://docs.aws.amazon.com/eks/latest/userguide/calico.html)  
[Determine best networking option](https://docs.tigera.io/calico/latest/networking/determine-best-networking)  
[Enable the eBPF dataplane](https://docs.tigera.io/calico/latest/operations/ebpf/enabling-ebpf#enable-ebpf-mode)  
