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

Export the Docker image to a local `tar` file (don't keep the `:` in the filename, SSH doesn't like it):
```sh
docker image save jenkins:2.410-py3 -o jenkins-2.410-py3.tar
```

>Copy that `tar` file to every K8s worker nodes. You can use whatever means you want, SSH, USB key or Fax 😀 See below for my shell script to copy the image to every nodes in a K8s cluster.

Import the local `tar` file as a local K8s image. You need to have `nerdctl` installed:
```sh
sudo nerdctl --namespace=k8s.io load -i jenkins-2.410-py3.tar
```

Check that this image has been imported:
```sh
# check the images
sudo nerdctl --namespace=k8s.io image ls
```

You should have your custom image on all your worker node in the cluster.

# Batch copy to all K8s nodes
If you want to copy the image to **ALL** your worker nodes, try this simple shell script:
```sh
#!/bin/bash

# Extract a Docker image from the local repo and copy it as a '.tar' file
# Copy that '.tar' file to all the worker node in a K8s cluster
# Import the '.tar' file in the local K8s repo

# Make sure your user can 'sudo' without password

# Docker image
DOCKER_IMAGE=jenkins
# Docker image TAG
DOCKER_TAG=2.410-py3

# User
USER=my_user

# Nodes in your K8s cluster
K8S_NODES=('s666dan4151' 's666dan4152' 's666dan4153' 's666dan4251')

# Domain for nodes
DNS_SUFFIX="example.com"

# Extract Docker image to '.tar' file
docker save ${DOCKER_IMAGE}:${DOCKER_TAG} -o ${DOCKER_IMAGE}.tar

for NODE in "${K8S_NODES[@]}"
do
  echo ">> scp file ${DOCKER_IMAGE}.tar on node $NODE.$DNS_SUFFIX"
  scp ${DOCKER_IMAGE}.tar $USER@$NODE.$DNS_SUFFIX:/tmp/.

  echo ">> Import image ${DOCKER_IMAGE}.tar in local K8s repo on node $NODE.$DNS_SUFFIX"
  ssh $NODE "sudo nerdctl --namespace=k8s.io load -i /tmp/${DOCKER_IMAGE}.tar && \
  rm -f ${DOCKER_IMAGE}.tar"

  echo ">> Done for node $NODE.$DNS_SUFFIX ..."
  echo ""
```
