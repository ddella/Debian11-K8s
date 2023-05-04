# Helm
Helm is a Kubernetes Package Manager. Helm is a tool for managing Charts. Charts are packages of pre-configured Kubernetes resources.

Helm is a tool that streamlines installing and managing Kubernetes applications. Think of it like apt/yum/homebrew for Kubernetes.

## Install Helm
This demonstartes how to install Heml from binary.

1. Getb the laatest version
2. Download Helm client from the Releases page and Unpack the helm binary
3. Move it to `/usr/local/bin` and you are good to go!
4. Cleanup

## 1. Get the latest version of Helm
```sh
VER=$(curl -s https://api.github.com/repos/helm/helm/releases/latest|grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo $VER
```

## 2. Download and extract the archive file from Github Helm releases page
```sh
curl -o helm-v${VER}-linux-amd64.tar.gz https://get.helm.sh/helm-v${VER}-linux-amd64.tar.gz
tar xvf helm-v${VER}-linux-amd64.tar.gz
```

## 3. Move Helm binary package to /usr/local/bin directory with the command
```sh
sudo mv linux-amd64/helm /usr/local/bin/.
```

## 4. Cleanup
```sh
rm -rf linux-amd64/
rm -f helm-v${VER}-linux-amd64.tar.gz
```
