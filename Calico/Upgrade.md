# Upgrading an installation that uses the operator
This page describes how to upgrade Calico from Calico v3.0 or later. The procedure varies by datastore type and install method. In this case we're using the `Tigera Operator`.

## Get the latest version number of `calico`
```sh
VER=$(curl -s https://api.github.com/repos/projectcalico/calico/releases/latest | grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo $VER
```

>**Wait**: Make sure your actual version can be upgraded to the latest version

## Download Tigera Calico operator manifest file
```sh
curl -LO https://raw.githubusercontent.com/projectcalico/calico/v${VER}/manifests/tigera-operator.yaml
```

## Upgrade
Use the following command to initiate an upgrade:
```sh
kubectl replace -f tigera-operator.yaml
```

Output:
```
namespace/tigera-operator replaced
customresourcedefinition.apiextensions.k8s.io/bgpconfigurations.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/bgpfilters.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/bgppeers.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/blockaffinities.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/caliconodestatuses.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/clusterinformations.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/felixconfigurations.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/globalnetworkpolicies.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/globalnetworksets.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/hostendpoints.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/ipamblocks.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/ipamconfigs.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/ipamhandles.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/ippools.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/ipreservations.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/kubecontrollersconfigurations.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/networkpolicies.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/networksets.crd.projectcalico.org replaced
customresourcedefinition.apiextensions.k8s.io/apiservers.operator.tigera.io replaced
customresourcedefinition.apiextensions.k8s.io/imagesets.operator.tigera.io replaced
customresourcedefinition.apiextensions.k8s.io/installations.operator.tigera.io replaced
customresourcedefinition.apiextensions.k8s.io/tigerastatuses.operator.tigera.io replaced
serviceaccount/tigera-operator replaced
clusterrole.rbac.authorization.k8s.io/tigera-operator replaced
clusterrolebinding.rbac.authorization.k8s.io/tigera-operator replaced
deployment.apps/tigera-operator replaced
```

# Upgrade `calicoctl` utility
Don't forget to upgrade `calicoctl` binary on all the hosts where it's installed.

Use the following command to download the `calicoctl` binary file:
```sh
curl -L https://github.com/projectcalico/calico/releases/latest/download/calicoctl-linux-amd64 -o calicoctl
```

Set the file to be executable, set owner and move it to `/usr/local/bin/`:
```sh
chmod +x ./calicoctl
sudo mv calicoctl /usr/local/bin
sudo chown root:adm /usr/local/bin/calicoctl
```

# Upgrade Verification
Verify that the upgrade has been successfully completed with the command:
```sh
calicoctl version
```

Output:
```
Client Version:    v3.26.1
Git commit:        b1d192c95
Cluster Version:   v3.26.1
Cluster Type:      typha,kdd,k8s,operator,bgp,kubeadm
```

In my case I upgraded Calico from 3.26.0 to 3.26.1.

# Reference
[Upgrade Calico](https://docs.tigera.io/calico/latest/operations/upgrading/kubernetes-upgrade#upgrading-an-installation-that-uses-the-operator)
