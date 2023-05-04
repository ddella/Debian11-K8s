# Upgrade Cilium
This upgrade guide is intended for Cilium running on Kubernetes.

Check the running version **before** the upgrade with the command:
```sh
cilium version
```

This is the output:

    cilium-cli: v0.13.2 compiled with go1.20.2 on linux/amd64
    cilium image (default): v1.13.1
    cilium image (stable): v1.13.2
    cilium image (running): v1.13.1

# Pre flight check

## Setup Helm repository:
```sh
helm repo add cilium https://helm.cilium.io/
```

>**Note**: Should be done only once for the live of the node

## Running pre-flight check (Required)
This will create a file named `cilium-preflight.yaml`

```sh
helm template cilium/cilium --version 1.13.2 \
  --namespace=kube-system \
  --set preflight.enabled=true \
  --set agent=false \
  --set operator.enabled=false \
  > cilium-preflight.yaml
```

Apply the manifest:
```sh
kubectl create -f cilium-preflight.yaml
```

## Check the Pods
After applying the `cilium-preflight.yaml`, ensure that the number of READY pods is the same number of Cilium pods running.
```sh
kubectl get daemonset -n kube-system | sed -n '1p;/cilium/p'
```

>Once the number of READY pods are equal, make sure the Cilium pre-flight deployment is also marked as READY 1/1.

```sh
kubectl get deployment -n kube-system cilium-pre-flight-check -w
```

When you see `READY 1/1` hit CTRL-C and move to the next step.

## Clean up pre-flight check
Once the number of READY for the preflight DaemonSet is the same as the number of cilium pods running and the preflight Deployment is marked as READY 1/1 you can delete the cilium-preflight and proceed with the upgrade.

```sh
kubectl delete -f cilium-preflight.yaml
```
# Upgrading Cilium

## Generate the required YAML file and deploy it:
This will create a file named `cilium.yaml`

```sh
helm template cilium/cilium --version 1.13.2 \
  --set upgradeCompatibility=1.13.1 \
  --namespace kube-system \
  > cilium.yaml
```

Apply the manifest:
```sh
kubectl apply -f cilium.yaml
```

The upgrade is completed.

# Check the final version
Check the running version **after** the upgrade with the command:
```sh
cilium version
```

This is the output:

    cilium-cli: v0.13.2 compiled with go1.20.2 on linux/amd64
    cilium image (default): v1.13.1
    cilium image (stable): v1.13.2
    cilium image (running): v1.13.2

# Reference
https://docs.cilium.io/en/stable/operations/upgrade/
