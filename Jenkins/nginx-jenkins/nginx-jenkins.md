# Create the mount point on the NFS server for Nginx
This tutorial is about configuring an Nginx reverse proxy to front the Jenkins API server. I found it easier to configure a reverse proxy then installing a TLS certificate on Jenkins 😉

When a request arrives for Jenkins URLs, Nginx becomes a proxy and further forward that request to Jenkins, then it forwards the response back to the client.

This assumes that:
- Jenkins runs on port 8080 with HTTP
- Internally Jenkins runs in a Kubernetes cluster and can be reached via the URL: http://jenkins-service.jenkins-ns.svc.cluster.local:8080
- Externally Nginx can be reached via the URL: https://jen.example.com:31443

Nginx will run as a deployment in a Kubernetes cluster in it's own namespace. The configuration of Nginx is stored in a Persistent Volume store on a Linux NFS server.


##  What is a Reverse Proxy
A `reverse proxy` allows an alternate HTTP or HTTPS provider to communicate with web browsers on behalf of Jenkins. The alternate provider may offer additional capabilities, like TLS encryption. The alternate provider may offload some work from Jenkins.

In this tutorial, Nginx Reverse proxy receive inbound `HTTPS` requests and forward those requests in `HTTP` to Jenkins. It receives the outbound `HTTP` response from Jenkins and forwards those requests to the original requester in `HTTPS`. A correctly configured reverse proxy rewrites both the HTTPS request and the HTTP response.


## Create directories
Create 2 directories on the NFS server.
- `html` is for site content
- `conf` all the configuration files for Nginx including the certificate and private key (**DON'T DO THAT IN PRODUCTION**)

```sh
sudo mkdir -p /mnt/nginx-jenkins/{html,conf}
sudo chown -R nobody:nogroup /mnt/nginx-jenkins
sudo chmod 777 /mnt/nginx-jenkins/
```

## Export directory
The `exports` file controls which file systems are exported to remote hosts and specifies options.
```sh
cat << EOF | sudo tee -a /etc/exports
/mnt/nginx-jenkins 192.168.13.0/24(rw,sync,no_subtree_check)
EOF
```

## Enable changes to `/etc/exports` file
```sh
sudo exportfs -arv
```

# On the NFS server
Add a configuration file for all Nginx Pods acting as a reverse proxy. The directory `/etc/nginx/conf.d`, inside each container, is mapped in `/mnt/nginx-jenkins/conf` on the NFS server.
```sh
$ sudo vi /mnt/nginx-jenkins/conf/jenkins.conf
```

Edit the file `jenkins.conf` and adjust:
- the certificate and private key
- the `proxy_pass` which is the URL of Jenkins
- the `proxy_redirect` which is the URL of the Kubernetes service name and the external URL (this one is `HTTPS`)

```
server {
    listen 443 ssl;

    #location / {
    #    root /usr/share/nginx/html/;
    #}

    server_name jen.example.com;

    access_log      /etc/nginx/conf.d/jenkins.access.log;
    error_log       /etc/nginx/conf.d/jenkins.error.log;

    ssl_certificate       /etc/nginx/conf.d/jen.corp.example.test.crt;
    ssl_certificate_key   /etc/nginx/conf.d/jen.corp.example.test.key;

    ssl_session_cache  builtin:1000  shared:SSL:10m;
    ssl_protocols  TLSv1.3 TLSv1.2;
    ssl_ciphers HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4;
    ssl_prefer_server_ciphers on;

    location / {
      proxy_set_header   Host              $http_host;
      proxy_set_header   X-Real-IP         $remote_addr;
      proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
      proxy_set_header   X-Forwarded-Proto https;

      #proxy_set_header  X-Forwarded-Port  31443;
      #proxy_set_header  X-Forwarded-Host  $http_host;

      # Fix the "It appears that your reverse proxy set up is broken" error.
      proxy_pass          http://jenkins-service.jenkins-ns.svc.cluster.local:8080;
      proxy_read_timeout  90;
      proxy_redirect      http://jenkins-service.jenkins-ns.svc.cluster.local:8080 https://jen.example.com:31443;
    }
}
```
# References
[Jenkins - Reverse proxy - Nginx](https://www.jenkins.io/doc/book/system-administration/reverse-proxy-configuration-nginx/)
[](https://www.jenkins.io/doc/book/system-administration/reverse-proxy-configuration-with-jenkins/reverse-proxy-configuration-nginx/)

