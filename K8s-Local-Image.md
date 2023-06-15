# Local Image in K8s
You may want to run a locally build Docker image in K8s. In this article, I’ll show how to run locally built images in K8s without publishing it to an external registry. For this article, I suppose you already have:

- A K8s cluster
- `kubectl` installed on the control plane
- `nerdctl` installed on **ALL** the nodes, master and worker

I'm using the Jenkins image that I added Python3.

## Build the image with Docker
Build the image with `docker build` command (make sure `Dockerfile` is in your directory):
```sh
docker build . -t jenkins:2.410-py3.tar
```

In case you're interested, here's my `Dockerfile`

```
FROM jenkins/jenkins:2.410
USER root
RUN apt update && apt install -y python3-pip
USER jenkins
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]
```

## Test the new image (Optional)
You can test the image by running the container. This is optional:
```sh
docker run --rm -d --name jenkins -p 8080:8080 -p 50000:50000 jenkins:2.410-py3
```

## Import in local K8s registry
We need to import the Docker image, from local Docker registry, to the local K8s local registry. This is a 2 step process:
1. Export the Docker image from the local registry to a local `tar` file. This is done once, no matter how many K8s worker nodes you have.
2. Import the `tar` file in the local K8s registry on **EACH WORKER NODE**. If you don't import the image on **EVERY WORKER NODE**, you will end up with the famous `ErrImagePull`.

Export the Docker image to a local `tar` file:
```sh
docker image save jenkins:2.410-py3 -o jenkins:2.410-py3.tar
```

Import the local `tar` file as a local K8s image. You need to have `nerdctl` installed:
```sh
sudo nerdctl --namespace=k8s.io load -i jenkins:2.410-py3.tar
```

Check that this image has been imported:
```sh
# crictl images
sudo nerdctl --namespace=k8s.io image ls
```

## Deploy the new image
You are now ready to deploy the new image to all the Pods. This is the command I used to replace the Pods with new one:
```sh
kubectl set image deployments/jenkins jenkins=jenkins:2.410-py3 -n jenkins-ns
```

## Rollout
Incase it doesn't work, you can rollout. Check the history and rollout to the version before the last:
```sh
kubectl rollout history deployment/jenkins  -n jenkins-ns
```

Output:
```
deployment.apps/jenkins
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
3         <none>
```

Rollout with this command:
```sh
kubectl rollout undo deployment/jenkins --to-revision=2 -n jenkins-ns
```

Output:
```
deployment.apps/jenkins rolled back
```
