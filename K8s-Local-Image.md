# Local Image in K8s
You may want to run a locally build Docker image in K8s. In this article, I’ll show how to run locally built images in K8s without publishing it to an external registry. For this article, I suppose you already have:

- A K8s cluster
- `kubectl` installed on the control plane
- `nerdctl` installed on **ALL** the nodes, master and worker

I'm using a standard Jenkins image to which I added Python 3.

## Build the image with Docker
Start by building the image with the staandard and well known command `docker build` (make sure `Dockerfile` is in your current directory):
```sh
docker build . -t jenkins:2.410-py3.tar
```

>**Note:**Add a tag to every image you build, trust me it will save you down the road 😉

In case you're interested, here's my `Dockerfile`
```
FROM jenkins/jenkins:2.410
USER root
RUN apt update && apt install -y python3-pip
USER jenkins
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/jenkins.sh"]
```

## Test the new image (Optional)
You can test the image by running the container (Optional):
```sh
docker run --rm -d --name jenkins -p 8080:8080 -p 50000:50000 jenkins:2.410-py3
```

## Import in local K8s registry
We need to import the Docker image you just build from the local Docker registry to the local K8s local registry. This is a 2 step process:
1. Export the Docker image from the local registry to a local `tar` file. This is done once, no matter how many K8s worker nodes you have.
2. Import the `tar` file in the local K8s registry on **EACH WORKER NODE**. If you don't import the image on **EVERY WORKER NODE**, you will end up with the famous `ErrImagePull` when the Pod is schedule on the worker node not having the image.

Export the Docker image to a local `tar` file:
```sh
docker image save jenkins:2.410-py3 -o jenkins:2.410-py3.tar
```

>Copy that `tar` file to every K8s worker nodes. Ypu whatever means you want, SSH, USB key or Fax 😀

Import the local `tar` file as a local K8s image. You need to have `nerdctl` installed:
```sh
sudo nerdctl --namespace=k8s.io load -i jenkins:2.410-py3.tar
```

Check that this image has been imported:
```sh
# crictl images
sudo nerdctl --namespace=k8s.io image ls
```

You should have your custom image on all your worker node in the cluster.
