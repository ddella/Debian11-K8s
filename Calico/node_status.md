# Calico Node Status
 Calico node status resource (`CalicoNodeStatus`) represents a collection of status information for a node that Calico reports back to the user for use during troubleshooting. Calico node status resource is only valid when Calico BGP networking is in use.

 >**Notes:**The updating of CalicoNodeStatus will have a small performance impact on CPU/Memory usage of the node as well as adding load to kubernetes apiserver.

## Create Node Status
To use this function, the user creates a `CalicoNodeStatus` object for the node, specifying the information to collect and the interval it should be collected at. This example collects information for node `k8sworker1` with an update interval of 10 seconds.

```sh
cat <<EOF | tee worker1-status.yaml > /dev/null
apiVersion: projectcalico.org/v3
kind: CalicoNodeStatus
metadata:
  name: k8sworker1-nodestatus
spec:
  classes:
    - Agent
    - BGP
    - Routes
  node: k8sworker1
  updatePeriodSeconds: 10
EOF
```

Create the `CalicoNodeStatus` with the command:
```sh
kubectl create -f worker1-status.yaml
```

## Get Node Status
The user then reads back the same resource using the command:

```sh
kubectl get caliconodestatus k8sworker1-nodestatus -o yaml
```

## Delete Node Status
Delete the `CalicoNodeStatus` with the command:
```sh
kubectl delete -f worker1-status.yaml
```

# Reference
[Calico Node Status](https://docs.tigera.io/calico/latest/reference/resources/caliconodestatus
)