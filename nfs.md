<a name="readme-top"></a>

# NFS Server and Client configuration
## Definition of NFS
Network File System (NFS), is a distributed file system that allows various clients to access a shared directory on a server.

## Lab
For this tutorial we have 2 Debian 11 system on the same network. NFS uses a client/server model, we will use the following configuration:

| Type         | Hostname             | IP address    |
|--------------|----------------------|---------------|
| NFS server   | debian1.example.com  | 192.168.13.41 |
| NFS client   | debian2.example.com  | 192.168.13.42 |

## Update Client and Server
Make sure that client and server are up to date with the following commands:
```sh
sudo apt update
sudo apt -y upgrade
```

# Configuration of NFS Server on Debian 11 (**Server ONLY**)
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
sudo mkdir /data
```

Change the permissions and ownership to match the following (Be sure that you know what you are doing):
```sh
sudo chown -R nobody: /data/
sudo chmod -R 777 /data/
```

Create the file exports for NFS:
```sh
cat << EOF | sudo tee -a /etc/exports
/data 192.168.13.0/24(rw,no_subtree_check,no_root_squash)
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

<p align="right">(<a href="#readme-top">back to top</a>)</p>

# Configuration of NFS Client on Debian 11 (**Client ONLY**)
Install NFS client:
```sh
sudo apt install nfs-common
```

Create a mount point directory to map the NFS share:
```sh
mkdir ~/mnt/
```

Edit the file `/etc/fstab` and add the following line to mount NSF without root:
```sh
debian1.example.com:/data /home/daniel/mnt nfs rw,user,noauto
```

Mount the NFS drive (remove the `-vvvv` to be less verbose):
```sh
mount -vvvv debian1.example.com:/data ~/mnt/
```

# Reference

<p align="right">(<a href="#readme-top">back to top</a>)</p>
