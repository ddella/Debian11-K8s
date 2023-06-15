# Helm Chart
Helm is a package manager for Kubernetes that allows you to quickly install full, pre-defined applications into a Kubernetes cluster. Helm manages charts and charts are packages of pre-configured Kubernetes resources. It streamlines installing and managing Kubernetes applications. Think of it like `apt/yum/homebrew` for Kubernetes. Jenkins has an official Helm chart, so we'll use Helm for the installation.

## Installing Helm
This demonstartes how to install Helm from binary.

1. Get the latest version
2. Download Helm client from the Releases page and Unpack the helm binary
3. Move it to `/usr/local/bin` and you are good to go 😀
4. Cleanup
5. Test

### 1. Get the latest version of Helm
```sh
VER=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo $VER
```

### 2. Download and extract the archive file from Github Helm releases page
Extract the `tar.gz` locally. We want only the binary file from it.
```sh
curl -o helm-v${VER}-linux-amd64.tar.gz https://get.helm.sh/helm-v${VER}-linux-amd64.tar.gz
tar xvf helm-v${VER}-linux-amd64.tar.gz
```

## 3. Move Helm binary package to `/usr/local/bin` directory with the command
```sh
sudo mv linux-amd64/helm /usr/local/bin/.
```

### 4. Test the binary
```sh
helm version --template='Helm Version: {{printf "%s\n\n" .Version}}'
```

### 5. Cleanup
```sh
rm -rf linux-amd64/
rm -f helm-v${VER}-linux-amd64.tar.gz
unset VER
```