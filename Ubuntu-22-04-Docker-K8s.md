<a name="readme-top"></a>

# Setup a Kubernetes Cluster with Kubeadm on Ubuntu 22.04.2

## Versions
As of writing this tutorial, those were the latest versions.
|Name|Version|
|:---|:---|
|**VMware ESXi/Fusion**|7.0 U2 / 13.0.2|
|**Ubuntu 22.04.2 LTS (Jammy Jellyfish)**|22.04.2|
|**Kernel**|6.3.3-060303|
|**Docker-CE**|24.0.1|
|**Containerd**|1.6.21|
|**K8s**|1.27.2|
|**Cilium**|1.13.2|

# Introduction
The step-by-step guide demonstrates how to install a Kubernetes cluster on Ubuntu 22.04.2 server edition with Kubeadm utility for a learning environment. All the Ubuntu hosts are running as VMs on VMware Fusion.

This Kubernetes (K8s) cluster is composed of one master node and three worker nodes. Master node works as the control plane and the worker nodes runs the actual container(s) inside Pods.

**This tutorial in not meant for production installation and is not a tutorial on Ubuntu intallation**. The tutorial main goal is to understand how to install a basic on-prem K8s cluster to get acquainted with the technology. In this tutorial we are **not** installing Docker.

In this tutorial, you will set up a Kubernetes Cluster by:

- Setting up four Ubuntu 22.04 virtual machines with Kernel 6.3.3
- Installing [Containerd](https://containerd.io/) as the CRI for K8s
- Installing Kubernetes kubelet, kubeadm, and kubectl
- Installing [Cilium](https://cilium.io/) as the CNI Plugin
- Initializing one K8s master node and adding three worker nodes
- The K8s master node will also run NFS server

At the end you will have a complete K8s cluster ready to run your Pods.

# Prerequisites
To complete this tutorial, you will need the following:

- Four physical/virtual Ubuntu servers
    - if you already have four Ubuntu installed, skip to <a href="#docker-ce">Docker-CE</a>
- Minimum of 2 vCPU with 4 GB RAM for the master node (Nothing as such is required for the worker node)
- 20 GB free disk space
- Internet Connectivity

# Lab Setup
For this tutorial, I will be using four Ubuntu 22.04.2 systems with following hostnames, IP addresses, OS, Kernel:

## Configurations
|Role|FQDN|IP|OS|Kernel|RAM|vCPU|
|----|----|----|----|----|----|----|
|Master|k8smaster1.example.com|192.168.13.30|Ubuntu 22.04.2|6.3.3|4G|4|
|Worker|k8sworker1.example.com|192.168.13.35|Ubuntu 22.04.2|6.3.3|4G|4|
|Worker|k8sworker2.example.com|192.168.13.36|Ubuntu 22.04.2|6.3.3|4G|4|
|Worker|k8sworker3.example.com|192.168.13.37|Ubuntu 22.04.2|6.3.3|4G|4|

<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Download the ISO file
Download Ubuntu server ISO [ubuntu-22.04.2-live-server-amd64.iso](https://releases.ubuntu.com/jammy/ubuntu-22.04.2-live-server-amd64.iso).

# Create the virtual Machine on VMware ESXi/Fusion
Create a virtual machine and start the installation. I used `Ubuntu Server (minimized)` with SSH server. Customize the network connections for your network.
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Use SSH to access the VM
After the initial Ubuntu setup, use SSH to access the VM, you'll have access to copy/paste 😉
```sh
ssh -l <USERNAME> 192.168.13.xxx
```

### Customize network options (Optional)
This should not be requited since you should have done it in the initial phase of the install. In case you need to customize it, you can edit the file `00-installer-config.yaml` to configure the network interface:

```sh
sudo vi  /etc/netplan/00-installer-config.yaml
```

Adapt to your network:
```
#  /etc/netplan/00-installer-config.yaml
version: 2
network:
ethernets:
    ens160:
    dhcp4: false
    addresses:
    - 192.168.13.180/24
    nameservers:
        addresses:
        - 9.9.9.9
        - 149.112.112.112
        search:
        - example.com
    routes:
    - to: default
        via: 192.168.13.1
```

To apply changes to `netplan` you will need to reload your Netplan network configurations with:
```sh
sudo netplan apply
```

### Domain name
Below is the command to add a domain name using the command line on Ubuntu 22.04 (replace `k8smaster1.example.com` with your hostname).
```sh
sudo hostnamectl hostname k8smaster1.example.com
```

Verify the change the has been apply:
```sh
sudo hostnamectl status
hostname -f
hostname -d
```

### Installing latest Linux kernel 6.3.x on Ubuntu (Optional)
I wanted to have the latest stable Linux kernel which was 6.3.3 at the time of this writing.

1. Make sure you have you packages are up to date.

```sh
sudo apt update && sudo apt upgrade
```
2. Ubuntu Mainline Kernel script (available on [GitHub](https://github.com/pimlie/ubuntu-mainline-kernel.sh))
Use this Bash script for Ubuntu (and derivatives such as LinuxMint) to easily (un)install kernels from the [Ubuntu Kernel PPA](http://kernel.ubuntu.com/~kernel-ppa/mainline/).

```sh
wget https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh
```

Make the file executable and copy it to `/usr/local/bin/`:
```sh
chmod +x ubuntu-mainline-kernel.sh
sudo mv ubuntu-mainline-kernel.sh /usr/local/bin/
```

3. Find the latest version of the Linux Kernel (Optional)
We can use the Ubuntu Mainline Kernel script to find what is the latest available version of the Linux kernel to install on our Ubuntu system. For that on your command terminal run:

```sh
ubuntu-mainline-kernel.sh -c
```

4. Installing latest Linux 6.x Kernel on Ubuntu
To install the latest Linux kernel package which is available in the repository of https://kernel.ubuntu.com, use the command:
```sh
sudo ubuntu-mainline-kernel.sh -i
```

5. Reboot

```sh
sudo init 6
```

6. List old kernels on your system (Optional)
You can delete the old kernels to free disk space.

```sh
dpkg --list | grep linux-image
```

Remove old kernels listing from the preceding step with the command (adjust the image name):
```sh
sudo apt --purge remove linux-image-5.15.0-72-generic
```

After removing the old kernel, update the grub2 configuration:
```sh
sudo update-grub2
```

### Install Utilities (optional)
Some usefull utilities that might bu usefull down the road. Take a look and feel free to add or remove:
```sh
sudo apt install -y bash-completion
sudo apt install -y iputils-tracepath iputils-ping iputils-arping
sudo apt install -y dnsutils
sudo apt install -y tshark
sudo apt install -y netcat
sudo apt install -y traceroute
sudo apt install -y vim
sudo apt install -y jq
```

(Optional) To remove a package with its configuration, data and all of its dependencies, you can use the following command:
```sh
sudo apt -y autoremove --purge <package name>
```

### SSH
Generate an ECC SSH public/private key pair. This should be done for each user you add to the system:
```sh
ssh-keygen -q -t ecdsa -N '' -f ~/.ssh/id_ecdsa <<<y >/dev/null 2>&1
```

If you want to be able to SSH from your PC to the newly created VM, you need to copy your public key to the new VM. Use this command to copy your public key to your new Ubuntu:

**THIS COMMAND IS EXECUTED FROM YOUR PC, NOT FROM THE NEW UBUNTU VM**
```sh
ssh-copy-id -i ~/.ssh/id_ecdsa.pub 192.168.13.3x
```

>**Note:** If you don't have an ECC public key, change the filename

### Disable swap space
K8s requires that swap partition be **disabled** on master and worker node of a cluster. As of this writing, Ubuntu 22.04 with minimal install has swap space disabled by default. If the case of Ubuntu 22.04, swap is disabled. You can skip to the next section if this is the case.

You can check if swap is enable with the command:
```sh
sudo swapon --show
```

There should be no output if swap disabled.

You can also check by running the `free` command:
```sh
free -h
```

If and **ONLY** if it's enabled, follow those steps to disable it.

Disable swap and comment a line in the file `/etc/fstab` with this command:
```sh
sudo swapoff -a
sudo sed -i '/swap/ s/./# &/' /etc/fstab
```

Delete the swap file
```sh
sudo rm /swap.img
```

### Disable IPv6 (Optional)
I've decided to disable IPv6. This is optional.

```sh
sudo tee /etc/sysctl.d/60-disable-ipv6.conf<<EOF
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
``` 

### Make iptables see the bridged traffic
Make sure that the `br_netfilter` module is loaded or `kubeadm` will fail with the error `[ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: /proc/sys/net/bridge/bridge-nf-call-iptables does not exist`.

Check if the module is loaded with this command. If it's running skip to the next section:
```sh
lsmod | grep br_netfilter
```

You can load it explicitly with the command:
```sh
sudo modprobe br_netfilter
```

Make the module load everytime the node reboots:
```sh
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF
```

### IPv4 routing
Make sure IPv4 routing is enabled. The following command returns `1` if IP routing is enabled, else it will return `0`: 
```sh
sysctl net.ipv4.ip_forward
```

If the the result is not `1`, meaning it's not enabled, you can modify the file `/etc/sysctl.conf` and uncomment the line `#net.ipv4.ip_forward=1` or just add the following file to enable IPv4 routing:
```sh
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
```

Reload sysctl with the command:
```sh
sudo sysctl --system
```

### Terminal color (Optional)
If you like a terminal prompt with colors, add those lines to your `~/.bashrc`. Lots of Linux distro have a red prompt for `root` and `green` for normal users. I decided to have `CYAN` for normal users to show that I'm in Kubernetes. Adjust to your preference:
```sh
cat >> .bashrc <<'EOF'
# Taken from: https://robotmoon.com/bash-prompt-generator/
if [[ $EUID = 0 ]]; then
  PS1="\[\e[38;5;196m\]\u\[\e[38;5;202m\]@\[\e[38;5;208m\]\h \[\e[38;5;220m\]\w \[\033[0m\]$ "
else
  PS1="\[\e[38;5;39m\]\u\[\e[38;5;81m\]@\[\e[38;5;77m\]\h \[\e[38;5;226m\]\w \[\033[0m\]$ "
fi

alias k='kubectl'
EOF
```
>**Note:** Make sure to surround `'EOF'` with single quotes. Failure to do so will replace variables with their value.

After you apply the change, the prompt should now be Cyan:
```sh
source .bashrc
```

### set timezone
Adjust for your timezone. You can list the available timezones with the command `timedatectl list-timezones`:
```sh
sudo timedatectl set-timezone America/Montreal
```

You should have a standard Ubuntu 22.04 installation 🎉
- with no graphical user interface
- a non-administrative user account with `sudo` privileges
- SSH server with public/private key
- Latest Kernel available

### Set bash auto completion
I like bash auto completion, so let's activate it:
```sh
grep -wq '^source /etc/profile.d/bash_completion.sh' ~/.bashrc || echo 'source /etc/profile.d/bash_completion.sh'>>~/.bashrc
source .bashrc
```

### Clean up (optional)
Use this command to uninstall unused packages:
```sh
sudo apt autoremove
```

<a name="docker-ce"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Install K8s cluster on Ubuntu 22.04 with Kubebadm (master & worker)
Finally the fun part 😀 As stated earlier, the lab used in this guide has four servers – one K8s Master Node and three K8s Worker nodes, where containerized workloads will run. Additional master and worker nodes can be added to suit your desired environment load requirements. For HA, three control plane nodes are required (for a cluster with `n` members, quorum is `(n/2)+1`).

## This needs to be done on both the Master(s) and the Worker(s) nodes of a K8s cluster
Install packages dependency. It should already be installed from the Docker section:
```sh
sudo apt install apt-transport-https ca-certificates
```

Download Google Cloud Public (GCP) signing key using curl command:
```sh
curl -sS https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/k8s-archive-keyring.gpg
```

Add the Kubernetes repository:
```sh
echo "deb [signed-by=/usr/share/keyrings/k8s-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Update the software package index. You shouldn't have any warnings about Kubernetes public key:
```sh
sudo apt update
```

Install Kubernetes with the following command:
```sh
sudo apt install -y kubectl kubelet kubeadm
```

Optional:
The following command hold back packages to prevent any updates with `apt`. I didn't do it in my lab:
```sh
sudo apt-mark hold kubectl kubelet kubeadm
```

Verify K8s version:
```sh
kubectl version --output=yaml
kubeadm version --output=yaml
```

>You'll get the following error message from **kubectl**: `The connection to the server localhost:8080 was refused - did you specify the right host or port?`. We haven't installed anything yet. It's a normal problem 😂!

Enable `kubectl` and `kubeadm` autocompletion for Bash:
```sh
sudo kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
sudo kubeadm completion bash | sudo tee /etc/bash_completion.d/kubeadm > /dev/null
```

After reloading your shell, `kubectl` and `kubeadm` autocompletion should be working.
```sh
source ~/.bashrc
```

<a name="k8s-master"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Install `containerd` on Ubuntu (Master and Worker nodes)
To run containers in Pods, Kubernetes needs a Container Runtime Engine. That CRE must be compliant with K8s Container Runtime Interface (CRI). CRE runs containers on a host operating system and is responsible for loading container images from a repository, monitoring local system resources, isolating system resources for use of a container, and managing container lifecycle. 

The supported CRI with K8s are:

- Docker
- CRI-O
- **Containerd**

For this tutorial, we will install [containerd](https://containerd.io/) as our CRE. Containerd is officially a graduated project within the Cloud Native Computing Foundation as of 2019 🍾🎉🥳🎁

install packages to allow apt to use a repository over HTTPS:
```sh
sudo apt -y install apt-transport-https ca-certificates
```

Add Docker's Official GPG Key:
```sh
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

Add Docker Repo to Ubuntu 22.04:
```sh
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Refresh the package list and make sure there's no error regarding the `gpg key`:
```sh
sudo apt update
```

To install the latest up-to-date Docker release on Ubuntu, run the below command:
```sh
sudo apt install containerd.io
```

Verify that containerd is indeed installed:
```sh
dpkg -l containerd.io
```

Output:
```
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name           Version      Architecture Description
+++-==============-============-============-======================================
ii  containerd.io  1.6.21-1     amd64        An open and reliable container runtime
```

### Containerd configuration (Master and Worker nodes)
Prepare the configuration of `containerd` on **both master and worker** nodes. If you start `kubeadm ...` without adjusting the configuration, you will get the following error:

```
[preflight] Running pre-flight checks
error execution phase preflight: [preflight] Some fatal errors occurred:
        [ERROR CRI]: container runtime is not running: output: time="2023-05-18T18:56:56Z" level=fatal msg="validate service connection: CRI v1 runtime API is not implemented for endpoint \"unix:///var/run/containerd/containerd.sock\": rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService"
, error: exit status 1
```

Prepare `containerd` configuration file for K8s:
```sh
sudo rm /etc/containerd/config.toml
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
```

Edit the configuration file `/etc/containerd/config.toml`. In the section `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]`, change the key `SystemdCgroup` to true. You can use the following command or your prefered text editor:
```sh
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
```

If you don't want to specify the endpoint every time you use the command `crictl`, you can create the file `/etc/crictl.yaml` by specifying the endpoint. If you don't create the file, you'll have to enter the endpoint each time like this: `crictl --runtime-endpoint unix:///run/containerd/containerd.sock ...`
```sh
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
EOF
```

Enable `crictl` autocompletion for Bash:
```sh
sudo crictl completion | sudo tee /etc/bash_completion.d/crictl > /dev/null
source ~/.bashrc
```
### Use `crictl` without sudo
By default each time you run the command `crictl` you'll need to prefix it with `sudo`. You can change the group permission of the API socket by:
- adding a new group like `crictl`
- add your user(s) to the group `crictl`
- modify the file `/etc/containerd/config.toml` to change the group owner of `/var/run/containerd/containerd.sock`

Add a new group to run the command `crictl` commands without using `sudo`:
```sh
sudo addgroup crictl
```

Enabling your non-root user to be part of the group `crictl`(Log out from the current terminal and log back in):
```sh
sudo usermod -aG crictl ${USER}
```

Modify the file `/etc/containerd/config.toml` to change the GID of `/var/run/containerd/containerd.sock` to the GID of the group `crictl`:
```sh
sudo sed -i "s/gid = 0/gid = $(getent group crictl | cut -d: -f3)/" /etc/containerd/config.toml
```

Restart the `containerd.service` service and check that it has been restarted without any **ERROR MESSAGES**:
```sh
sudo systemctl restart containerd.service
sudo systemctl status containerd.service
```

The file `/run/containerd/containerd.sock` should be owned by the group `crictl` 
```
srw-rw---- 1 root crictl 0 May 23 08:31 /run/containerd/containerd.sock
```

Logoff and log back in for the changes to take effect and test the command without `sudo`:
```sh
crictl version
```

The output should look like this:

    Version:  0.1.0
    RuntimeName:  containerd
    RuntimeVersion:  1.6.21
    RuntimeApiVersion:  v1

### Install `nerdctl` (DOESN'T WORK !!!)
ContaiNERD CTL is a command-line tool for managing containers for the `containerd` Container Runtime. It's compatible with Docker CLI for Docker and has the same UI/UX as the "docker" command. 

Get the latest version and download `nerdctl` binary file. Extract it to `/usr/local/bin`:

1. Get the latest version of `nerdctl`:
```sh
VER=$(curl -s https://api.github.com/repos/containerd/nerdctl/releases/latest | grep tag_name | cut -d '"' -f 4|sed 's/v//g')
echo $VER
```

2. Download and extract the archive file from Github nerdctl releases page
```sh
curl -LO https://github.com/containerd/nerdctl/releases/download/v${VER}/nerdctl-${VER}-linux-amd64.tar.gz
```
 
3. Move `nerdctl` binary package to `/usr/local/bin` directory with the command:
```sh
# mkdir nerdctl-${VER}-linux-amd64
sudo tar Cxzvf /usr/local/bin nerdctl-${VER}-linux-amd64.tar.gz
```

```sh
echo "kernel.unprivileged_userns_clone = 1" | sudo tee /etc/sysctl.d/90-nerdctl-rootless.conf > /dev/null
sudo sysctl --system
sudo sysctl -p /etc/sysctl.d/90-nerdctl-rootless.conf
```

containerd-rootless-setuptool.sh install
 
4. Cleanup
```sh
rm -f nerdctl-full-${VER}-linux-amd64.tar.gz
unset VER
```

***** **STOP** *****

Congratulations! You have a fully functional Linux Ubuntu 22.04 ready for Kubernetes 🎉 You can `clone` the VM so you won't have to go over the preceding steps again 😀

If you're configuration a worker node skip to <a href="#k8s-worker">Configure K8s worker nodes</a>. If you're doing the K8s master node, just continue with <a href="#k8s-master">Configure a K8s master node</a>.

<a name="k8s-master"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Configure a K8s master node
This should only be done on the **master node** of a K8s cluster and **ONE** time only.

## Initialize K8s Master node
Initialize the master node with the command:
```sh
sudo kubeadm init --cri-socket unix:///var/run/containerd/containerd.sock --pod-network-cidr=10.255.0.0/16 --apiserver-advertise-address 192.168.13.30
```
>**Note:** The `--apiserver-advertise-address` argument is optional if you have only one network interface. Please be patient. It will take some time to init the master node.

This should be the result of the `kubeadm init` command. **Make a copy**:

    [init] Using Kubernetes version: v1.27.2
    [preflight] Running pre-flight checks
    [preflight] Pulling images required for setting up a Kubernetes cluster
    [preflight] This might take a minute or two, depending on the speed of your internet connection
    [preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
    W0522 11:21:45.907459    2173 images.go:80] could not find officially supported version of etcd for Kubernetes v1.27.2, falling back to the nearest etcd version (3.5.7-0)
    W0522 11:22:13.497376    2173 checks.go:835] detected that the sandbox image "registry.k8s.io/pause:3.6" of the container runtime is inconsistent with that used by kubeadm. It is recommended that using "registry.k8s.io/pause:3.9" as the CRI sandbox image.
    [certs] Using certificateDir folder "/etc/kubernetes/pki"
    [certs] Generating "ca" certificate and key
    [certs] Generating "apiserver" certificate and key
    [certs] apiserver serving cert is signed for DNS names [k8smaster1.isociel.com kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local] and IPs [10.96.0.1 192.168.13.30]
    [certs] Generating "apiserver-kubelet-client" certificate and key
    [certs] Generating "front-proxy-ca" certificate and key
    [certs] Generating "front-proxy-client" certificate and key
    [certs] Generating "etcd/ca" certificate and key
    [certs] Generating "etcd/server" certificate and key
    [certs] etcd/server serving cert is signed for DNS names [k8smaster1.isociel.com localhost] and IPs [192.168.13.30 127.0.0.1 ::1]
    [certs] Generating "etcd/peer" certificate and key
    [certs] etcd/peer serving cert is signed for DNS names [k8smaster1.isociel.com localhost] and IPs [192.168.13.30 127.0.0.1 ::1]
    [certs] Generating "etcd/healthcheck-client" certificate and key
    [certs] Generating "apiserver-etcd-client" certificate and key
    [certs] Generating "sa" key and public key
    [kubeconfig] Using kubeconfig folder "/etc/kubernetes"
    [kubeconfig] Writing "admin.conf" kubeconfig file
    [kubeconfig] Writing "kubelet.conf" kubeconfig file
    [kubeconfig] Writing "controller-manager.conf" kubeconfig file
    [kubeconfig] Writing "scheduler.conf" kubeconfig file
    [kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
    [kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
    [kubelet-start] Starting the kubelet
    [control-plane] Using manifest folder "/etc/kubernetes/manifests"
    [control-plane] Creating static Pod manifest for "kube-apiserver"
    [control-plane] Creating static Pod manifest for "kube-controller-manager"
    [control-plane] Creating static Pod manifest for "kube-scheduler"
    [etcd] Creating static Pod manifest for local etcd in "/etc/kubernetes/manifests"
    W0522 11:22:45.329284    2173 images.go:80] could not find officially supported version of etcd for Kubernetes v1.27.2, falling back to the nearest etcd version (3.5.7-0)
    [wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
    [apiclient] All control plane components are healthy after 7.005054 seconds
    [upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
    [kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
    [upload-certs] Skipping phase. Please see --upload-certs
    [mark-control-plane] Marking the node k8smaster1.isociel.com as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
    [mark-control-plane] Marking the node k8smaster1.isociel.com as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
    [bootstrap-token] Using token: t75vgu.9t1panzxtl6dxs45
    [bootstrap-token] Configuring bootstrap tokens, cluster-info ConfigMap, RBAC Roles
    [bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
    [bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
    [bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
    [bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
    [bootstrap-token] Creating the "cluster-info" ConfigMap in the "kube-public" namespace
    [kubelet-finalize] Updating "/etc/kubernetes/kubelet.conf" to point to a rotatable kubelet client certificate and key
    [addons] Applied essential addon: CoreDNS
    [addons] Applied essential addon: kube-proxy

    Your Kubernetes control-plane has initialized successfully!

    To start using your cluster, you need to run the following as a regular user:

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config

    Alternatively, if you are the root user, you can run:

    export KUBECONFIG=/etc/kubernetes/admin.conf

    You should now deploy a pod network to the cluster.
    Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
    https://kubernetes.io/docs/concepts/cluster-administration/addons/

    Then you can join any number of worker nodes by running the following on each as root:

    kubeadm join 192.168.13.30:6443 --token t75vgu.9t1panzxtl6dxs45 \
        --discovery-token-ca-cert-hash sha256:bfa012186a6accbf8fd9ccde522a71a396e173567f1397a504b4fd200349a0e6 

>Keep note of the hash but be aware that it's valid for 24 hours.

Execute those commands as a normal user:
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```
>**Note:** When you add a new user to administer K8s, don't forget to enter the above commands under that user.

Check the status of the master with the command:
```sh
kubectl get nodes -o=wide
```

The output should look like this:
```
NAME                     STATUS     ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
k8smaster1.isociel.com   NotReady   control-plane   98s   v1.27.2   192.168.13.30   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21
```

>**Note:** the “NotReady” status. This is because we have not yet installed a CNI plugin to provide networking functionnality. This is normal and to be expected 😉

Check the status of `kubelet`:
```sh
sudo systemctl status kubelet
```

>The only error message you'll get is `"Container runtime network not ready" networkReady="NetworkReady=false reason:NetworkPluginNotReady`

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## NFS Server
There's many Pods that requires persistent volume. Let's install an NFS server on the master node and share mount points.

Install NFS server:
```sh
sudo apt install nfs-kernel-server
```

Start the service:
```sh
sudo systemctl start nfs-kernel-server.service
sudo systemctl enable nfs-kernel-server.service
```

Create the mount point directory:
```sh
sudo mkdir /nfs-data
```

Change the permissions and ownership to match the following (Be sure that you know what you are doing):
```sh
sudo chown -R nobody: /nfs-data/
sudo chmod -R 777 /nfs-data/
```

Create the file exports for NFS:
```sh
cat << EOF | sudo tee -a /etc/exports
/nfs-data 192.168.13.0/24(rw,no_subtree_check,no_root_squash)
EOF
```

Export it to the client(s):
```sh
sudo exportfs -arv
```

>**Note:** Remember to re-export your shares on the server with exportfs -arv if you made changes! The NFS server won’t pick them up automatically. Display your currently running exports with `exportfs -v`.  

Verify the NFS version (you can see this information in column two):
```sh
rpcinfo -p | grep nfs
```

Congratulations! You have a fully functional Kubernetes cluster ... with just one Master node 😂

## Token and CA certificate hash (Optional)
This section is to get the token and certificate hash if you forgot to copy the output of `kubeadm init ...` command from the preceding step or if you wait more than 24 hours to add a worker node.
You can retreive the token by running the following command on the control-plane node. The token is only valid for 24 hours. It might be better to generate a new token:
```sh
kubeadm token list
```

You can retreive the CA certificate hash by running the following command on the control-plane node:
```sh
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \openssl dgst -sha256 -hex | sed 's/^.* //'
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>
<a name="k8s-worker"></a>

# Configure K8s worker nodes
This should be done on **all** worker node(s) of a K8s cluster and **ONLY** on the worker nodes. If you need three worker nodes, then repeat this section three times.

Join each of the worker node to the cluster with the command:

```sh
sudo kubeadm join 192.168.13.30:6443 --token t75vgu.9t1panzxtl6dxs45 \
--cri-socket unix:///var/run/containerd/containerd.sock \
--discovery-token-ca-cert-hash sha256:bfa012186a6accbf8fd9ccde522a71a396e173567f1397a504b4fd200349a0e6
```

The ouput should look like this:

    [preflight] Running pre-flight checks
    [preflight] Reading configuration from the cluster...
    [preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
    [kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
    [kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"
    [kubelet-start] Starting the kubelet
    [kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

    This node has joined the cluster:
    * Certificate signing request was sent to apiserver and a response was received.
    * The Kubelet was informed of the new secure connection details.

    Run 'kubectl get nodes' on the control-plane to see this node join the cluster.

Check that the worker node have joined the cluster and it's ready. Use this command on the **control plane** not the worker node:
```sh
kubectl get nodes -o=wide
```

You should see something similar after running the command on all your `worker node(s)`:

    NAME                     STATUS     ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
    k8smaster1.isociel.com   NotReady   control-plane   6m37s   v1.27.2   192.168.13.30   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21
    k8sworker1.isociel.com   NotReady   <none>          108s    v1.27.2   192.168.13.35   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21
    k8sworker2.isociel.com   NotReady   <none>          61s     v1.27.2   192.168.13.36   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21
    k8sworker3.isociel.com   NotReady   <none>          56s     v1.27.2   192.168.13.37   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21

>Repeat the steps above if you want more worker node.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Install NFS client
You need to install NFS client of each worker node for them to access the NFS server.

Install NFS client:
```sh
sudo apt install nfs-common
```

## Add Role (Optional)
As you see above, the role for worker node is ­­`<none>`, if you want to change it, you can add a label. The most important part in the label is the `Key`. The following two commands are executed on the **control plane**, not the worker node:
```sh
kubectl label node k8sworker1.isociel.com node-role.kubernetes.io/worker=myworker
kubectl label node k8sworker2.isociel.com node-role.kubernetes.io/worker=myworker
kubectl label node k8sworker3.isociel.com node-role.kubernetes.io/worker=myworker
```

You can remove the label with the command:
```sh
kubectl label node <hostname> node-role.kubernetes.io/worker-
```

<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Install Helm
[See this page to install Helm](https://github.com/ddella/Debian11-K8s/blob/main/helm.md)

# Install Cilium (Master node ONLY)
We're going to use [Cilium](https://cilium.io/) as our CNI networking solution. Cilium is an incubating CNCF project that implements a wide range of networking, security and observability features, much of it through the Linux kernel eBPF facility. This makes Cilium fast and resource efficient. We'll use Helm to install Cilium and active the metrics for Prometheus and Grafana.

Setup Helm repository:
```sh
helm repo add cilium https://helm.cilium.io/
```

Deploy Cilium via Helm as follows to enable all metrics:
```sh
helm install cilium cilium/cilium \
--namespace kube-system \
--set prometheus.enabled=true \
--set operator.prometheus.enabled=true \
--set hubble.enabled=true \
--set hubble.metrics.enableOpenMetrics=true \
--set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,httpV2:exemplars=true;labelsContext=source_ip\,source_namespace\,source_workload\,destination_ip\,destination_namespace\,destination_workload\,traffic_direction}"
```

Monitor the installation process with the command:
```sh
cilium status --wait
```

Check that the all the nodes in the K8s cluster are all in ready state:
```sh
kubectl get nodes -o=wide
```

    NAME                     STATUS   ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
    k8smaster1.isociel.com   Ready    control-plane   16m   v1.27.2   192.168.13.30   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21
    k8sworker1.isociel.com   Ready    worker          12m   v1.27.2   192.168.13.35   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21
    k8sworker2.isociel.com   Ready    worker          11m   v1.27.2   192.168.13.36   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21
    k8sworker3.isociel.com   Ready    worker          11m   v1.27.2   192.168.13.37   <none>        Ubuntu 22.04.2 LTS   6.3.3-060303-generic   containerd://1.6.21


Run the following command to validate that your cluster has proper network connectivity:
```sh
cilium connectivity test
```

Check the Pods for all namespace. You will see the Cilium Pods.
```sh
kubectl get pod -A
```

    NAMESPACE     NAME                                             READY   STATUS    RESTARTS   AGE
    kube-system   cilium-8pgq7                                     1/1     Running   0          3m49s
    kube-system   cilium-ccrgl                                     1/1     Running   0          3m49s
    kube-system   cilium-crjsl                                     1/1     Running   0          3m49s
    kube-system   cilium-jjrhs                                     1/1     Running   0          3m49s
    kube-system   cilium-operator-5bb89494dc-kg7rb                 1/1     Running   0          3m49s
    kube-system   coredns-5d78c9869d-98bvw                         1/1     Running   0          17m
    kube-system   coredns-5d78c9869d-v8qr6                         1/1     Running   0          17m
    kube-system   etcd-k8smaster1.isociel.com                      1/1     Running   0          17m
    kube-system   kube-apiserver-k8smaster1.isociel.com            1/1     Running   0          17m
    kube-system   kube-controller-manager-k8smaster1.isociel.com   1/1     Running   0          17m
    kube-system   kube-proxy-hh9kc                                 1/1     Running   0          12m
    kube-system   kube-proxy-lxkd2                                 1/1     Running   0          17m
    kube-system   kube-proxy-zc49j                                 1/1     Running   0          11m
    kube-system   kube-proxy-zl8zc                                 1/1     Running   0          11m
    kube-system   kube-scheduler-k8smaster1.isociel.com            1/1     Running   0          17m

Delete the Cilium package downloaded in the step above:
```sh
rm -f cilium-linux-amd64.tar.gz
```

Verify the status of `kubelet` and version:
```sh
sudo systemctl status kubelet.service
kubectl version --output=yaml
```

You should have a fully functionnal Kubernetes Cluster with one master node and three worker nodes 🥳🎉. The rest is optional.

# Uninstall Cilium (just in case 😀)
If you ever want to uninstall Cilium completely, use the commands below:
```sh
helm delete cilium --namespace kube-system
```

You shouldn't see any more Cilium Pods in the namespace `kube-system`
```sh
kubectl get all -n kube-system
```

All your K8s nodes will be in status `NotReady`:
```sh
kubectl get nodes
```

Output should look like this:
```
NAME                     STATUS     ROLES           AGE     VERSION
k8smaster1.isociel.com   NotReady   control-plane   6d19h   v1.27.2
k8sworker1.isociel.com   NotReady   worker          6d19h   v1.27.2
k8sworker2.isociel.com   NotReady   worker          6d19h   v1.27.2
k8sworker3.isociel.com   NotReady   worker          6d19h   v1.27.2
```

If you want to remove the images, go on each node (master and worker) and:
1. List the image(s)

List the local images:
```sh
crictl images ls
```

The ouput should look like this:
```
IMAGE                                     TAG                 IMAGE ID            SIZE
...
quay.io/cilium/alpine-curl                               <none>              678139ecf284d       7.67MB
quay.io/cilium/cilium                                    <none>              4cfc81d8cbe39       174MB
quay.io/cilium/cilium                                    <none>              2480b5e5b4799       174MB
quay.io/cilium/hubble-relay                              <none>              33706bf42661c       15.6MB
quay.io/cilium/hubble-ui-backend                         <none>              0631ce248fa69       16.6MB
quay.io/cilium/hubble-ui                                 <none>              b555a2c7b3de8       19.2MB
quay.io/cilium/json-mock                                 <none>              6d9eed9df4c1d       100MB
quay.io/cilium/operator-generic                          <none>              5e08056ff5956       22.2MB
...
```

2. Delete the Cilium images one by one with the command:
```sh
crictl rmi <IMAGE ID>
```

Or delete all the images at once with the command (use with caution!):
```sh
crictl image | grep cilium | awk '{ print $3 }' | xargs crictl rmi
```

>It needs to be done on all the nodes

# Install Hubble
Hubble is the observability layer of Cilium and can be used to obtain cluster-wide visibility into the network and security layer of your Kubernetes cluster.

See this page [Hubble](hubble.md)

# Install Prometheus and Grafana
See this page [Hubble](prometheus-grafana.md)


# Create a username to administor K8s (Optional)
If you need to create another username to administor K8s, follow thoses steps

## Create the user
Create the new username, assign the groups and set the password:
```sh
sudo useradd -s /bin/bash -m -G sudo,docker,crictl <username>
sudo passwd <username>
```

## Login with the new user
The new user can't administor K8s without the correct certificates. Login with the new user and copy the necessary files from the initial K8s installation:
```sh 
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

## SSH keys
Generate a public/private key pair for the new user:
```sh
ssh-keygen -q -t ecdsa -N '' -f ~/.ssh/id_ecdsa <<<y >/dev/null 2>&1
```
 If you want to login to the this node without password from another Linux, copy it's public key to the file `id_ecdsa.pub`:
```sh
ssh-copy-id -i ~/.ssh/id_ecdsa.pub 192.168.13.3x
```

# About

## License
Distributed under the MIT License. See [LICENSE](LICENSE) for more information.
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contact
Daniel Della-Noce - [Linkedin](https://www.linkedin.com/in/daniel-della-noce-2176b622/) - daniel@isociel.com  
Project Link: [https://github.com/ddella/Debian11-Docker-K8s](https://github.com/ddella/Debian11-Docker-K8s)
<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Reference
[Good reference for K8s and Ubuntu](https://computingforgeeks.com/install-kubernetes-cluster-ubuntu-jammy/)  
[Install latest Ubuntu Linux Kernel](https://linux.how2shout.com/linux-kernel-6-2-features-in-ubuntu-22-04-20-04/#5_Installing_Linux_62_Kernel_on_Ubuntu)  
[Containerd configuration file modification for K8s](https://devopsquare.com/how-to-create-kubernetes-cluster-with-containerd-90399ec3b810)  
[apt-key deprecated](https://itsfoss.com/apt-key-deprecated/)  
[Cilium Quick installation](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#k8s-install-quick)
