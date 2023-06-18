# Example 1

## Open another shell on the master node:
Watch the Pods being created 😀

    kubectl get pods --watch --show-labels

## Create the deployment

    kubectl create -f hello-dep-v1.yaml

## Check the images
Check that the images where downloaded successfuly:

    crictl images ls

## Get the list of Pods
You should have a Pod on each node

    kubectl get pods -o wide

## Get the Deployment info

    kubectl get deployment
    kubectl describe deployment hello-v1

## Get the ReplicaSet name

    kubectl get rs

## Describe the ReplicaSet

    kubectl describe rs <ReplicaSet name>

## From any node in the K8s cluster
Test the Pods from any node in the K8s cluster. (Change the IP address for one of the Pod):

    while true; do curl <IP address>; sleep 1; done

## Cleanup

    kubectl delete -f hello-dep-v1.yaml

## Remove the image(s) (Optional)

    docker rmi nginx
