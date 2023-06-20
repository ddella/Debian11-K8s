# Kubernetes Contexts

## Kubernetes namespaces and contexts
**Context** applies to the client-side of kubernetes, where you run the `kubectl` command.  
**Namespaces** applies to the server-side of Kubernetes.

As an example, in the command prompt, i.e. as the client:

- When executing `kubectl get pods -n dev`, you're retrieving the list of the pods located under the namespace 'dev' with the default 'client'.
- When executing `kubectl --kubeconfig=/path/to/kubeconfig get pods -n dev`, you're doing the same command as above but in the context of the config file `/path/to/kubeconfig`.

## Kubectl Configuration
The `kubectl` configuration file is a configuration file that stores all the information necessary to interact with a Kubernetes cluster. It is usually in `~/.kube/config` and contains the following information:

- The name of the Kubernetes cluster
- The location of the Kubernetes API server
- The Kubernetes certificate
- The client certificate and private key that serves as credentials for authenticating with the Kubernetes API server
- The names of all contexts defined in the cluster

## Display Kubernetes Configuration
Use this command to view the `kubectl` configuration:
```sh
kubectl config view
```

The output should look like this:
```
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: DATA+OMITTED
    server: https://10.250.12.180:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: kubernetes-admin
  name: kubernetes-admin@kubernetes
current-context: kubernetes-admin@kubernetes
kind: Config
preferences: {}
users:
- name: kubernetes-admin
  user:
    client-certificate-data: DATA+OMITTED
    client-key-data: DATA+OMITTED
```

>You could have done `cat ~/.kube/config` and you would have gotton almost the same output, execpt that you would have seen the certificates and private key

## KUBECONFIG
You can change the Kubernetes configuration in three ways:
- Use an environment varaible that points to a new configuration file:
  - `export KUBECONFIG=/path/to/kubeconfig`
- Append the `--kubeconfig=/path/to/kubeconfig` to every `kubectl` command:
  - `kubectl --kubeconfig=/path/to/kubeconfig get pods`
- Modify the default `~/.kube/config` file to have multiple context
- Use multiple contexts in the KUBECONFIG environment variable:
  - `export KUBECONFIG=/path/to/kubeconfig:/path/to/another/kubeconfig`

We'll explore the last option in this tutorial. You can change context using `kubectl config use-context <context-name>`.

## Retrieve your Current Context
Use the following command to get the current context:
```sh
kubectl config current-context
```

The output should look like this:
```
kubernetes-admin@kubernetes
```

## Lists all Kubernetes Contexts
Use the following command to list all of the available Kubernetes contexts:
```sh
kubectl config get-contexts
```

If you have a standard installation of `kubectl`, you should only see one context which is the default context:
```
CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
*         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin   
```

## Create new users
I will create two new users that will be admin in their own namespace. I used this [tutorial](Kubernetes-Admin-RBAC.md). I called the users `user1` and `user2`.

If you execute the command below, in my case, it will always be in the context of the namespace `user1-ns`:
```sh
kubectl --kubeconfig=config-user1 get pods
```

The output should look like this:
```
No resources found in user1-ns namespace.
```

```sh
kubectl --kubeconfig config-user2 get pods
```

```
No resources found in user2-ns namespace.
```

>I didn't specify the namespace because it's included in each config file. See below for `user2`
```
- context:
    cluster: kubernetes
    namespace: user2-ns
    user: user2
  name: user2@kubernetes
```

If I try to lis the Pods in namespace `user1-ns` from the context of `user2` it will be forbidden. See the example below
```sh
kubectl --kubeconfig config-user2 get pods -n user1-ns
```

```
Error from server (Forbidden): pods is forbidden: User "user2" cannot list resource "pods" in API group "" in the namespace "user1-ns"
```

## Merging contexts
For the next scenario, I'll combined my original config file with the one from `user1` and `user2`.
```sh
# Make a copy of your existing config
cp ~/.kube/config ~/.kube/config.bak
# KUBECONFIG environment variable is a list of all configuration files
export KUBECONFIG=user1/config-user1:user2/config-user2:~/.kube/config.bak
# Merge all kubeconfig files into one
kubectl config view --flatten > ~/.kube/config
```

## Verify the merging
We should now have three context. The admin and one for each user we just created:
```sh
kubectl config get-contexts
```

The output should look like this:
```
CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
          kubernetes-admin@kubernetes   kubernetes   kubernetes-admin   
*         user1@kubernetes              kubernetes   user1              user1-ns
          user2@kubernetes              kubernetes   user2              user2-ns
```

Looks like we are in the context of `user1`. Let's try to list Pods:
```sh
kubectl get pods
```

```
No resources found in user1-ns namespace.
```

We are in the context of `user1`. We didn't specify any namespace and `kubectl` looked at namespace `user1-ns`.

## Change context
Let's try to change context as `user2` with the command:
```sh
kubectl config use-context user2@kubernetes
```

The output should look like this:
```
Switched to context "user2@kubernetes".
```

Now get all the Pods:
```sh
kubectl get pods
```

The output should look like this:
```
No resources found in user2-ns namespace.
```

We are in the context of `user2`. We didn't specify any namespace and `kubectl` looked at namespace `user2-ns`.

## Try another namespace
You should still be in context of `user2`, let's try to access the `default` namespace.
Now get all the Pods:
```sh
kubectl get pods -n default
```

The output should look like this:
```
Error from server (Forbidden): pods is forbidden: User "user2" cannot list resource "pods" in API group "" in the namespace "default"
```

The access is forbidden since `user2` can't access the  `default` namespace.

# Cleanup
Let's cleanup what we did and put everything back the way they were 😀
- the context
- the users

## The context
Overwrite the config file with the backup file:
```sh
# Copy the backup config on the main config file
cp ~/.kube/config.bak ~/.kube/config
# Unset KUBECONFIG
unset KUBECONFIG
# Delete the backup config file
rm ~/.kube/config.bak
```

Check that you have only one context:
```sh
kubectl config get-contexts
```

The output should look like this:
```
CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
*         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin   
```

## The users
You will have all the details to delete the users at the bottom of this [tutorial](Kubernetes-Admin-RBAC.md).
