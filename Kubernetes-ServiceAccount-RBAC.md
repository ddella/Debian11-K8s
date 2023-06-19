# **INCOMPLETE**
# Kubernetes RBAC
## Overview
Kubernetes Role-Based Access Control (RBAC) is a form of identity and access management (IAM) that involves a set of permissions or template that determines who (subjects) can execute what (verbs), where (namespaces). RBAC is an evolution from the traditional attribute-based access control (ABAC)which grants access based on user name rather than user responsibilities.

## Check RBAC status
Check whether RBAC’s available in your cluster by running the following command:
```sh
kubectl api-versions | grep rbac.authorization.k8s
```

The command should return `rbac.authorization.k8s.io/v1`, if RBAC is enabled and nothing if RBAC is disabled. 
```
rbac.authorization.k8s.io/v1
```

## Kubernetes RBAC Objects
The Kubernetes RBAC implementation revolves around four different object types. You can manage these objects using Kubectl, similarly to other Kubernetes resources like Pods, Deployments, and ConfigMaps.

- Role: A `role` is a set of access control rules that define actions which users can perform.
- RoleBinding: A `binding` is a link between a role and one or more subjects, which can be users or service accounts. The binding permits the subjects to perform any of the actions included in the targeted role.

`Roles` and `RoleBindings` are **namespaced** objects. They must exist within a particular namespace and they control access to other objects within it. RBAC is applied to cluster-level resources – such as Nodes and Namespaces themselves – using `ClusterRoles` and `ClusterRoleBindings`. These work similarly to `Role` and `RoleBinding` but target non-namespaced objects.

## Creating a Service Account
A Kubernetes service account is like a user that is managed by the Kubernetes API. Each service account has a unique token that is used as its credentials. You can’t add normal users via the Kubernetes API so we’ll use a service account for this tutorial.

Create a `yaml` file and use `kubectl` command to create a service account:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo
```

```sh
kubectl create -f demo-sa.yaml
```


Verify that the account has been created:
```sh
kubectl get serviceaccounts/demo -o yaml
```

The output should look like this:
```
apiVersion: v1
kind: ServiceAccount
metadata:
  creationTimestamp: "2023-06-19T00:25:53Z"
  name: demo
  namespace: default
  resourceVersion: "5651200"
  uid: 97ef473c-e618-4f35-a15f-dfd03f0f6567
```

## Cleanup
If you tried creating `demo` ServiceAccount from the example above, you can clean it up by running:
```sh
kubectl delete serviceaccount/demo
```
or
```sh
kubectl delete -f demo-sa.yaml
```

## Manually create an API token for a ServiceAccount
You can get a *time-limited* API token for that `ServiceAccount` using `kubectl`:

```sh
kubectl create token demo
```

The output from that command is a token that you can use to authenticate as that `ServiceAccount`.
```
eyJhbGciOiJSUzI1NiIsImtpZCI6Ilh5TWh1eHJrb3VuRVA1VXBJOUY3RnhnSVg3RTRoZXhlTnFGQ1llRldsZ1kifQ.eyJhdWQiOlsiaHR0cHM6Ly9rdWJlcm5ldGVzLmRlZmF1bHQuc3ZjLmNsdXN0ZXIubG9jYWwiXSwiZXhwIjoxNjg3MTM4NDE4LCJpYXQiOjE2ODcxMzQ4MTgsImlzcyI6Imh0dHBzOi8va3ViZXJuZXRlcy5kZWZhdWx0LnN2Yy5jbHVzdGVyLmxvY2FsIiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJkZWZhdWx0Iiwic2VydmljZWFjY291bnQiOnsibmFtZSI6ImRlbW8iLCJ1aWQiOiI5N2VmNDczYy1lNjE4LTRmMzUtYTE1Zi1kZmQwM2YwZjY1NjcifX0sIm5iZiI6MTY4NzEzNDgxOCwic3ViIjoic3lzdGVtOnNlcnZpY2VhY2NvdW50OmRlZmF1bHQ6ZGVtbyJ9.joklGfJ4bzx39s2RC7mqZAEmETLF8VWWRZ9es19cy_AJ0hg1DPlS8bTWUBfbUF8ZON878jH93cfFDGjoLKmxym7bXxarJ92MKSuowuaKGSvGhyD3ESNZRdH_NckZJi-uNPnCamAipUrbA2kuB5BBDk2gjSLCh9-HB2-EzeOXzECFYxhHVgTYKrKbIp6SID7Yq745xo4Hu-dmQTXnw_ahp5As0ihL-Fca7e52_12yE9YOeu_if8_N0tbNilPjn7vkFLJijjHfKP8iGhqRTt7f3YlRxHy2NfcnP-H8scfQmN8nY4NbB3qJI54QWdmV9ue6ZS9DOP1DWl9lg_FNOQsowg
```

## Context (INCOMPLETE)
Switch to your new context to authenticate as your `demo` service account. Note down the name of your currently selected context first, so you can switch back to your superuser account later on.

Get the current context with the command:
```sh
kubectl config current-context
```

This is my output from the command above:
```
kubernetes-admin@kubernetes
```

```sh
kubectl config use-context demo
```

Switched to context "demo".
