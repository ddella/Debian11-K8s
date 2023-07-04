# AWS Load Balancer Controller
## Create an IAM policy

1. Get the latest version:
```sh
VER=$(curl -s https://api.github.com/repos/kubernetes-sigs/aws-load-balancer-controller/releases/latest | grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo ${VER}
```

2. Download an IAM policy for the AWS Load Balancer Controller that allows it to make calls to AWS APIs on your behalf:
```sh
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v${VER}/docs/install/iam_policy.json
```

3. Create an IAM policy using the policy downloaded in the previous step:
```sh
aws iam create-policy --policy-name AWSLoadBalancerControllerIAMPolicy --policy-document file://iam_policy.json
```

Output:
``` 
{
    "Policy": {
        "PolicyName": "AWSLoadBalancerControllerIAMPolicy",
        "PolicyId": "ANPAYYC3DMJNFOH7G62NV",
        "Arn": "arn:aws:iam::111122223333:policy/AWSLoadBalancerControllerIAMPolicy",
        "Path": "/",
        "DefaultVersionId": "v1",
        "AttachmentCount": 0,
        "PermissionsBoundaryUsageCount": 0,
        "IsAttachable": true,
        "CreateDate": "2023-07-01T16:39:05+00:00",
        "UpdateDate": "2023-07-01T16:39:05+00:00"
    }
}
```

## Create an IAM role
You need to have `IAM OIDC provider` enabled, use this command:
```sh
eksctl utils associate-iam-oidc-provider --region=us-east-2 --cluster=my-cluster --approve
```

Output:
```
2023-07-01 12:47:26 [ℹ]  will create IAM Open ID Connect provider for cluster "calico-cni" in "us-east-2"
2023-07-01 12:47:26 [✔]  created IAM Open ID Connect provider for cluster "calico-cni" in "us-east-2"
```


```sh
eksctl create iamserviceaccount \
--cluster=my-cluster \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--role-name AmazonEKSLoadBalancerControllerRole \
--attach-policy-arn=arn:aws:iam::111122223333:policy/AWSLoadBalancerControllerIAMPolicy \
--approve
```

>Replace `my-cluster` with the name of your cluster, `111122223333` with your account ID

Output:
```
2023-07-01 12:49:16 [ℹ]  1 iamserviceaccount (kube-system/aws-load-balancer-controller) was included (based on the include/exclude rules)
2023-07-01 12:49:16 [!]  serviceaccounts that exist in Kubernetes will be excluded, use --override-existing-serviceaccounts to override
2023-07-01 12:49:16 [ℹ]  1 task: { 
    2 sequential sub-tasks: { 
        create IAM role for serviceaccount "kube-system/aws-load-balancer-controller",
        create serviceaccount "kube-system/aws-load-balancer-controller",
    } }2023-07-01 12:49:16 [ℹ]  building iamserviceaccount stack "eksctl-calico-cni-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2023-07-01 12:49:17 [ℹ]  deploying stack "eksctl-calico-cni-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2023-07-01 12:49:17 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2023-07-01 12:49:47 [ℹ]  waiting for CloudFormation stack "eksctl-calico-cni-addon-iamserviceaccount-kube-system-aws-load-balancer-controller"
2023-07-01 12:49:47 [ℹ]  created serviceaccount "kube-system/aws-load-balancer-controller"
```

## Install the AWS Load Balancer Controller using

1. Add the eks-charts repository and update your local repo to make sure that you have the most recent charts:
```sh
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks
```

2. Install the AWS Load Balancer Controller:
```sh
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller/crds?ref=master"
```


```sh
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
--set clusterName=my-cluster --set serviceAccount.create=false \
--set serviceAccount.name=aws-load-balancer-controller
```

```
NAME: aws-load-balancer-controller
LAST DEPLOYED: Sat Jul  1 12:53:24 2023
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
AWS Load Balancer controller installed!
```

## Verify that the controller is installed
```sh
kubectl get deployment -n kube-system aws-load-balancer-controller
```

The example output is as follows:
```
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           27s
```

# Reference
[AWS Load Balancer Controller - GitHub](https://github.com/aws/eks-charts/tree/master/stable/aws-load-balancer-controller)  
[AWS Load Balancer Controller - AWS](https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html)  
