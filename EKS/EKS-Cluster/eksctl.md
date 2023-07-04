# EKS CLI Installation
To download the latest release of `eksctl` utility, run:
```sh
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH
curl -sLO "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
# (Optional) Verify checksum for Linux
curl -sL "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
# Untar
sudo tar Cxzvf /usr/local/bin eksctl_$PLATFORM.tar.gz
# Set permission (adapt to your system)
sudo chown root:adm /usr/local/bin/eksctl
# Unset env. varibles
unset ARCH
unset PLATFORM
```

Enable eksctl bash-completion
```sh
eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion
```

## Test
```sh
eksctl version
```
