<a name="readme-top"></a>

# Setup a Kubernetes Cluster with Kubeadm on Ubuntu 22.04.2

## Last Version
|Name|Version|
|:---|:---|
|**VMware ESXi**|7.0 U2|
|**Ubuntu 22.04.2 LTS (Jammy Jellyfish)**|22.04.2|
|**Kernel**|6.3.2-060302|
|**Docker-CE**|24.0.0|
|**K8s**|1.27.2|
|**Cilium**|1.13.2|

# Introduction
The step-by-step guide demonstrates you how to install Kubernetes cluster on Ubuntu 22.04 with Kubeadm utility for a Learning environment. All the Ubuntu hosts are running as VMs on VMware Fusion.

This Kubernetes (K8s) cluster is composed of one master node and three worker nodes. Master node works as the control plane and the worker nodes runs the actual container(s) inside Pods.

**This tutorial in not meant for production installation and is not a tutorial on Ubuntu intallation**. The tutorial main goal is to understand how to install a basic on-prem K8s cluster.

In this tutorial, you will set up a Kubernetes Cluster by:

- Setting up four Ubuntu virtual machines with a Kernel 6.3.2
- Installing Docker-CE and Docker Compose plugin
- Installing CRI-Docker plugin
- Installing Kubernetes kubelet, kubeadm, and kubectl
- Installing a CNI Plugin (Cilium)
- Configuring Docker as the container runtime for Kubernetes
- Initializing one K8s master node and adding three worker nodes

At the end you will have a complete K8s cluster ready to run your microservices.

# Prerequisites
To complete this tutorial, you will need the following:

- Four physical/virtual Ubuntu servers
    - if you already have four Ubuntu installed, skip to <a href="#docker-ce">Docker-CE</a>
- Minimum of 2 CPU / vCPU with 8 GB RAM for the master node (Nothing as such is required for the worker node)
- 20 GB free disk space
- Internet Connectivity

# Lab Setup
For this tutorial, I will be using four Ubuntu 22.04 systems with following hostnames, IP addresses, OS, Kernel:

## Configurations
|Role|FQDN|IP|OS|Kernel|RAM|CPU|
|----|----|----|----|----|----|----|
|Master|k8smaster1.example.com|192.168.13.180|Ubuntu 22.04|6.3.2|4G|4|
|Worker|k8sworker1.example.com|192.168.13.185|Ubuntu 22.04|6.3.2|4G|4|
|Worker|k8sworker2.example.com|192.168.13.186|Ubuntu 22.04|6.3.2|4G|4|
|Worker|k8sworker3.example.com|192.168.13.187|Ubuntu 22.04|6.3.2|4G|4|

<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Download the ISO file
Download the [ubuntu-22.04.2-live-server-amd64.iso](https://releases.ubuntu.com/jammy/ubuntu-22.04.2-live-server-amd64.iso) from a Ubuntu.

# Create the virtual Machine on VMware ESXi

<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Start the installation of Debian Linux
Choose standard text installation

## Finalize Ubuntu installation
Use the VMware console to login with the `root` user account.

### Get the IP address of the VM
Find your network interface name and ip address with the command:

    ip addr

### Use SSH to access the VM
Use SSH to access the VM, you'll have access to copy/paste. You should have the IP address from the step above. Use the non-administrative user since `root` is not allowed to SSH.
    ssh -l <USERNAME> 192.168.13.xxx

### Configuring static IP address
Edit the file `00-installer-config.yaml` to configure a static IP address:

```sh
sudo vi  /etc/netplan/00-installer-config.yaml
```

Add the following lines (adapt to your network):

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

### Installing latest Linux kernel 6.3.x on Ubuntu (Optional)
I wanted to have a Linux kernel 6.3.x in my lab.

1. Make sure you have you packages are up to date.

```sh
sudo apt update && sudo apt upgrade
```
2. Ubuntu Mainline Kernel script (available on [GitHub](https://github.com/pimlie/ubuntu-mainline-kernel.sh))
Use this Bash script for Ubuntu (and derivatives as LinuxMint) to easily (un)install kernels from the [Ubuntu Kernel PPA](http://kernel.ubuntu.com/~kernel-ppa/mainline/).

```sh
wget https://raw.githubusercontent.com/pimlie/ubuntu-mainline-kernel.sh/master/ubuntu-mainline-kernel.sh
```

Once the Kernel has been installed, reboot the server with the command:
```sh
chmod +x ubuntu-mainline-kernel.sh
sudo mv ubuntu-mainline-kernel.sh /usr/local/bin/
```

3. Find the latest version of the Linux Kernel
We can use the Ubuntu Mainline Kernel script to find what is the latest available version of the Linux kernel to install on our Ubuntu system. For that on your command terminal run:

```
ubuntu-mainline-kernel.sh -c
```

4. Installing latest Linux 6.x Kernel on Ubuntu
To install the latest Linux kernel package which is available in the repository of https://kernel.ubuntu.com, we can use

```
sudo ubuntu-mainline-kernel.sh -i
```

5. Reboot

```
sudo init 6
```

6. List old kernels on your system (Optional)
You can delete the old kernels to free disk space.

```sh
dpkg --list | grep linux-image
```

Remove old kernels listing from the preceding step with the command:

```sh
sudo apt-get --purge remove linux-image-5.19.0-41-generic
```

After removing the old kernel, update the grub2 configuration:
```sh
sudo update-grub2
```

### SSH
Generate an ECC SSH public/private key pair
```sh
ssh-keygen -q -t ecdsa -N '' -f ~/.ssh/id_ecdsa <<<y >/dev/null 2>&1
```

Copy SSH public key from VMware host to master and worker nodes:
```sh
ssh-copy-id -i ~/.ssh/id_ecdsa.pub 192.168.13.18x
```

### Disable swap space
K8s requires that swap partition be **disabled** on master and worker node of a cluster.

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

### IPv4 routing
Make sure IPv4 routing is enabled.

```sh
sysctl net.ipv4.ip_forward
```

The result should be this if it's enables:
```
net.ipv4.ip_forward = 1
```

If it's not enabled, you can modify the file `/etc/sysctl.conf` and uncomment the line `#net.ipv4.ip_forward=1` or just add the following file:
```sh
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.ipv4.ip_forward = 1
EOF
```

Reload sysctl with the command:
```sh
sudo sysctl --system
```

### Terminal color (Optional)
If you like a terminal with colors, add those lines to your `~/.bashrc`:
```sh
NORMAL="\[\e[0m\]"
RED="\[\e[1;31m\]"
GREEN="\[\e[1;32m\]"
CYAN="\[\e[1;35m\]"
ALIASE_NAME="k8master1"
if [[ $EUID = 0 ]]; then
  PS1="$RED\u [ $NORMAL\w$RED ]# $NORMAL"
else
  PS1="$CYAN$ALIASE_NAME@\u [ $NORMAL\w$CYAN ]\$ $NORMAL"
fi
 
unset RED GREEN NORMAL CYAN
```

### set timezone
```sh
sudo timedatectl set-timezone America/Montreal
```

You should have a standard Ubuntu 22.04 installation with no graphical user interface, a non-administrative user account with `sudo` privileges and SSH server.

<a name="docker-ce"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Install Docker-CE on Ubuntu
For this tutorial, I'm using Docker container runtime. This is applicable to master and worker node in a K8s cluster.

Install Prerequisites:
```sh
sudo apt install apt-transport-https ca-certificates curl software-properties-common
```

Add Docker's Official GPG Key:
```sh
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
```

Add Docker Repo to Ubuntu 22.04:
```sh
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

Refresh the package list:
```sh
sudo apt update
```

To install the latest up-to-date Docker release on Ubuntu, run the below command:
```sh
sudo apt install docker-ce
```

Check the Docker service status using the following command:
```sh
sudo systemctl is-active docker
```

Enabling your non-root user to run Docker commands without using `sudo` (Log out from the current terminal and log back in)
```sh
sudo usermod -aG docker ${USER}
```
>**Note**: Logoff and login

Check Docker's version (without sudo):
```sh
docker version
docker compose version
```

Verify that Docker and ContainerD are running and that there's **NO ERROR MESSAGES**:
```sh
sudo systemctl status docker.service
sudo systemctl status docker.socket
sudo systemctl status containerd.service
```

If you installed `docker-ce-cli` package Docker bash completion should already be installed:
```sh
dpkg -L docker-ce-cli | grep completion
```

The steps above installed the following Docker components:

- docker-ce: The Docker engine itself.
- docker-ce-cli: A command line tool that lets you talk to the Docker daemon.
- containerd.io: A container runtime that manages the container’s lifecycle.
- docker-buildx-plugin: A CLI plugin that extends the Docker build with many new features.
- docker-compose-plugin: A configuration management plugin to orchestrate the creation and management of Docker containers through compose files.

<a name="cri-docker"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Install K8s cluster on Ubuntu 22.04 with Kuebadm (master & worker)
Finally the fun part 😀  
As stated earlier, the lab used in this guide has four servers – One K8s Master Node and three K8s Worker nodes where containerized workloads will run. Additional master and worker nodes can be added to suit your desired environment load requirements. For HA, three control plane nodes are required with control plane API endpoint (For a cluster with n members, quorum is (n/2)+1).

## This needs to be done on both the Master(s) and the Worker(s) nodes of a K8s cluster
Install packages dependency (should already be installed from the Docker section):
```sh
sudo apt install apt-transport-https ca-certificates curl
```

Download the Google Cloud public (GCP) signing key using curl command:
```sh
sudo curl -fsSL  https://packages.cloud.google.com/apt/doc/apt-key.gpg|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/k8s.gpg
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
```

Add Kubernetes APT Repository:
```sh
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Update the software package index:
```sh
sudo apt update
```

Install Kubernetes with the following commands:
```sh
sudo apt install -y kubectl kubeadm kubelet
```

Optional:
The follwoing command will make sure that `apt upgrade` won't upgrade K8s:
```sh
sudo apt-mark hold kubelet kubeadm kubectl
```

Verify K8s version (v1.27.1):
```sh
kubectl version --output=yaml
kubeadm version --output=yaml
```

>You'll get the following error message from **kubectl**: `The connection to the server localhost:8080 was refused - did you specify the right host or port?`. We haven't installed anything yet!

Enable kubectl autocompletion for Bash:
```sh
sudo kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
```

After reloading your shell, kubectl autocompletion should be working.
```sh
source ~/.bashrc
```

<a name="k8s-master"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Install Container runtime (Master and Worker nodes)
To run containers in Pods, Kubernetes uses a container runtime. The supported container runtimes are:

- Docker
- CRI-O
- Containerd

I've decided to use **Containerd**, since even Docker uses it. The good news is since we installed Docker, we already have installed **Containerd**. Just verify with the command:

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
Prepare the configuration of `containerd` on both master and worker nodes. If you start `kubeadm ...` you will get the following error:

```
[preflight] Running pre-flight checks
error execution phase preflight: [preflight] Some fatal errors occurred:
        [ERROR CRI]: container runtime is not running: output: time="2023-05-18T18:56:56Z" level=fatal msg="validate service connection: CRI v1 runtime API is not implemented for endpoint \"unix:///var/run/containerd/containerd.sock\": rpc error: code = Unimplemented desc = unknown service runtime.v1.RuntimeService"
, error: exit status 1
```

Prepare `containerd` configuration file for K8s:
```sh
sudo rm /etc/containerd/config.toml
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

Edit the configuration file
```sh
sudo vi /etc/containerd/config.toml
```

In the section `[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]`, change the key `systemdcgroup` to true:
```
SystemdCgroup = true
```

Restart `containerd`, check that it has been restarted and that there's **NO ERROR MESSAGES**:
```sh
sudo systemctl restart containerd
sudo systemctl status containerd
```

# Configure a K8s master node
This should only be done on the **master node** of a K8s cluster and **ONE** time only. Initialize the master node with the command:
```sh
sudo kubeadm init --cri-socket unix:///var/run/containerd/containerd.sock --pod-network-cidr=10.255.0.0/16 --apiserver-advertise-address 192.168.13.180
```
>**Note:** The `--apiserver-advertise-address` argument is optional if you have only one network interface.

This should be the result of the `kubeadm init` command. Make a copy:

    [init] Using Kubernetes version: v1.27.2
    [preflight] Running pre-flight checks
    [preflight] Pulling images required for setting up a Kubernetes cluster
    [preflight] This might take a minute or two, depending on the speed of your internet connection
    [preflight] You can also perform this action in beforehand using 'kubeadm config images pull'
    W0519 14:43:17.229110  173807 images.go:80] could not find officially supported version of etcd for Kubernetes v1.27.2, falling back to the nearest etcd version (3.5.7-0)
    W0519 14:43:17.368383  173807 checks.go:835] detected that the sandbox image "registry.k8s.io/pause:3.6" of the container runtime is inconsistent with that used by kubeadm. It is recommended that using "registry.k8s.io/pause:3.9" as the CRI sandbox image.
    [certs] Using certificateDir folder "/etc/kubernetes/pki"
    [certs] Generating "ca" certificate and key
    [certs] Generating "apiserver" certificate and key
    [certs] apiserver serving cert is signed for DNS names [kubernetes kubernetes.default kubernetes.default.svc kubernetes.default.svc.cluster.local host4051] and IPs [10.96.0.1 192.168.13.180]
    [certs] Generating "apiserver-kubelet-client" certificate and key
    [certs] Generating "front-proxy-ca" certificate and key
    [certs] Generating "front-proxy-client" certificate and key
    [certs] Generating "etcd/ca" certificate and key
    [certs] Generating "etcd/server" certificate and key
    [certs] etcd/server serving cert is signed for DNS names [localhost host4051] and IPs [192.168.13.180 127.0.0.1 ::1]
    [certs] Generating "etcd/peer" certificate and key
    [certs] etcd/peer serving cert is signed for DNS names [localhost host4051] and IPs [192.168.13.180 127.0.0.1 ::1]
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
    W0519 14:43:19.975449  173807 images.go:80] could not find officially supported version of etcd for Kubernetes v1.27.2, falling back to the nearest etcd version (3.5.7-0)
    [wait-control-plane] Waiting for the kubelet to boot up the control plane as static Pods from directory "/etc/kubernetes/manifests". This can take up to 4m0s
    [apiclient] All control plane components are healthy after 4.501798 seconds
    [upload-config] Storing the configuration used in ConfigMap "kubeadm-config" in the "kube-system" Namespace
    [kubelet] Creating a ConfigMap "kubelet-config" in namespace kube-system with the configuration for the kubelets in the cluster
    [upload-certs] Skipping phase. Please see --upload-certs
    [mark-control-plane] Marking the node host4051 as control-plane by adding the labels: [node-role.kubernetes.io/control-plane node.kubernetes.io/exclude-from-external-load-balancers]
    [mark-control-plane] Marking the node host4051 as control-plane by adding the taints [node-role.kubernetes.io/control-plane:NoSchedule]
    [bootstrap-token] Using token: i1v6yb.csh8zm02ffm85fvh
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

    kubeadm join 192.168.13.180:6443 --token i1v6yb.csh8zm02ffm85fvh \
            --discovery-token-ca-cert-hash sha256:9a374ad0f3b7dea59b44979241bdd0d432d9da0de35705022cb5909fee75b03d

>Keep note of the hash but be aware that it's valid for 24 hours.

Execute those commands as a normal user:
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

Check the status of the master with the command:
```sh
kubectl get nodes -o=wide
```

The output should look like this:
```
NAME          STATUS     ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
host4051   NotReady   control-plane   5m37s   v1.27.2   192.168.13.180   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21
```

The status is `NotReady` because we didn't install a CNI.

Check the status of `kubelet`:
```sh
sudo systemctl status kubelet
```

>The only error message you'll get is `"Container runtime network not ready"`

### New user
When you add a new user to administer K8s, don't forget to enter those commands:
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

You will get this message if you don't enter the preceeding commands:

    kubectl get nodes
    E0505 09:34:01.117879 1899475 memcache.go:265] couldn't get current server API group list: Get http://localhost:8080/api?timeout=32s: dial tcp [::1]:8080: connect: connection refused
 
<a name="k8s-worker"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Token and CA certificate hash

If you forgot to copy the token, you can get it by running the following command on the control-plane node:
```sh
kubeadm token list
```

If you forgot to copy the CA certificate hash, you can get it by running the following command on the control-plane node:
```sh
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \openssl dgst -sha256 -hex | sed 's/^.* //'
```

## Configure the k8s worker nodes
This should be done on **all** worker node(s) of a K8s cluster and **ONLY** the worker nodes.

Join each of the worker node to the master node with the command:

```sh
sudo kubeadm join 192.168.13.180:6443 --token i1v6yb.csh8zm02ffm85fvh \
--cri-socket unix:///var/run/containerd/containerd.sock \
--discovery-token-ca-cert-hash sha256:9a374ad0f3b7dea59b44979241bdd0d432d9da0de35705022cb5909fee75b03d
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

Check that the worker node have joined the cluster and they're ready. Use this command on the **control plane**:
```sh
kubectl get nodes -o=wide
```

You should see something similar:

    NAME          STATUS     ROLES           AGE   VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
    host4051   NotReady   control-plane   76m   v1.27.2   192.168.13.180   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21
    host4151   NotReady   <none>          48s   v1.27.2   192.168.13.185   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21

### Add Role (Optional)
As you see above, the role for worker node is ­­`<none>`, if you want to change it you can add a label:
```sh
kubectl label node host4151 node-role.kubernetes.io/worker=myworker
```

You can remove the label with the command:
```sh
kubectl label node host4151 node-role.kubernetes.io/worker-
```

<a name="k8s-cilium"></a>
<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Verification
Verify the status of the K8s cluster. You can see that we're using Docker as the container runtime engine.
```sh
kubectl get nodes -o wide
```

    NAME          STATUS     ROLES           AGE     VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
    host4051   NotReady   control-plane   125m    v1.27.2   192.168.13.180   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21
    host4151   NotReady   worker          50m     v1.27.2   192.168.13.185   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21
    host4152   NotReady   worker          4m7s    v1.27.2   192.168.13.186   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21
    host4153   NotReady   worker          3m54s   v1.27.2   192.168.13.187   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21

## Install Cilium (Master node ONLY)
We're going to use Cilium as our CNI networking solution. Cilium is an incubating CNCF project that implements a wide range of networking, security and observability features, much of it through the Linux kernel eBPF facility. This makes Cilium fast and resource efficient. Cilium offers a command line tool that we can use to install the CNI components.
1.	Download
2.	Extract
3.	Install and test the Cilium CLI:

>**Note:** On master node only

Download the package:
```sh
wget https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz
```

Extract it:
```sh
sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
```

Install cilium CNI (be patient):
```sh
cilium install
```

>**Note:** If the install fail, run it again

To validate that Cilium has been properly installed, you can run:
```sh
cilium status
```

The ouput should look like this. Initially `Hubble Relay` is disabled for now:

        /¯¯\
    /¯¯\__/¯¯\    Cilium:          OK
    \__/¯¯\__/    Operator:        OK
    /¯¯\__/¯¯\    Hubble Relay:    disabled
    \__/¯¯\__/    ClusterMesh:     disabled
        \__/

    DaemonSet         cilium             Desired: 4, Ready: 4/4, Available: 4/4
    Deployment        cilium-operator    Desired: 1, Ready: 1/1, Available: 1/1
    Containers:       cilium             Running: 4
                    cilium-operator    Running: 1
    Cluster Pods:     2/2 managed by Cilium
    Image versions    cilium             quay.io/cilium/cilium:v1.13.2@sha256:85708b11d45647c35b9288e0de0706d24a5ce8a378166cadc700f756cc1a38d6: 4
                    cilium-operator    quay.io/cilium/operator-generic:v1.13.2@sha256:a1982c0a22297aaac3563e428c330e17668305a41865a842dec53d241c5490ab: 1



Run the following command to validate that your cluster has proper network connectivity:
```sh
cilium connectivity test
```

Check that the master and worker nodes are ready:
```sh
kubectl get nodes -o=wide
```

    NAME          STATUS   ROLES           AGE    VERSION   INTERNAL-IP     EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION         CONTAINER-RUNTIME
    host4051   Ready    control-plane   142m   v1.27.2   192.168.13.180   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21
    host4151   Ready    worker          66m    v1.27.2   192.168.13.185   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21
    host4152   Ready    worker          20m    v1.27.2   192.168.13.186   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21
    host4153   Ready    worker          20m    v1.27.2   192.168.13.187   <none>        Ubuntu 22.04.2 LTS   6.3.2-060302-generic   containerd://1.6.21

Check the Pods for all namespace. You will see the Cilium Pods.
```sh
kubectl get pod -A
```

    NAMESPACE     NAME                                  READY   STATUS    RESTARTS   AGE
    cilium-test   client-6965d549d5-hgxg8               1/1     Running   0          22m
    cilium-test   client2-76f4d7c5bc-lhrv6              1/1     Running   0          22m
    cilium-test   echo-other-node-f57db5457-vxxxd       2/2     Running   0          22m
    cilium-test   echo-same-node-799c9b99f-q9frr        2/2     Running   0          22m
    kube-system   cilium-8pzz5                          1/1     Running   0          26m
    kube-system   cilium-operator-5bb89494dc-9ndmd      1/1     Running   0          26m
    kube-system   cilium-p8kql                          1/1     Running   0          26m
    kube-system   cilium-ttzx5                          1/1     Running   0          26m
    kube-system   cilium-x4z4h                          1/1     Running   0          26m
    kube-system   coredns-5d78c9869d-4dtcm              1/1     Running   0          164m
    kube-system   coredns-5d78c9869d-flsd8              1/1     Running   0          164m
    kube-system   etcd-host4051                         1/1     Running   228        164m
    kube-system   kube-apiserver-host4051               1/1     Running   210        164m
    kube-system   kube-controller-manager-host4051      1/1     Running   219        164m
    kube-system   kube-proxy-7rqv9                      1/1     Running   0          43m
    kube-system   kube-proxy-gm7g6                      1/1     Running   0          89m
    kube-system   kube-proxy-sqtpd                      1/1     Running   0          164m
    kube-system   kube-proxy-vgbqb                      1/1     Running   0          43m
    kube-system   kube-scheduler-host4051               1/1     Running   235        164m

Delete the Cilium package:
```sh
rm -f cilium-linux-amd64.tar.gz
```

Verify the status of `kubelet` and version:
```sh
sudo systemctl status kubelet.service
kubectl version --output=yaml
```

You should have a fully functionnal Kubernetes Cluster running on four nodes.

# Install Helm
[See this page to install Helm](https://github.com/ddella/Debian11-K8s/blob/main/helm.md)


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
