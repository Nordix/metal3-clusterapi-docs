# TopoLVM dev setup

Development setup for [TopoLVM](https://github.com/Nordix/topolvm).

## Requirements

- Go 1.16
- Make
- GCC
- Docker

```bash
# Better update first
sudo apt update
sudo apt upgrade
# Install required packages
sudo apt install make gcc

# Install Docker CE: https://docs.docker.com/engine/install/ubuntu/
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io

sudo adduser $USER docker
# Log out and in again or run
newgrp docker

# Install go: https://go.dev/doc/install
wget https://go.dev/dl/go1.16.10.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.16.10.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.profile
go version
```

Now you are ready to build and test TopoLVM!

```bash
# Clone repository
git clone https://github.com/Nordix/topolvm.git
cd topolvm

# Setup local environment
make setup

# Run unit tests
make test

# Clean up
make clean

# End-2-end tests. See https://github.com/Nordix/topolvm/tree/main/e2e
# E2e with kind
make -C e2e setup
make -C e2e start-lvmd
make -C e2e test
make -C e2e clean
# E2e with minikube
make -C e2e setup
make -C e2e daemonset-lvmd/create-vg
make -C e2e daemonset-lvmd/setup-minikube
make -C e2e daemonset-lvmd/update-minikube-setting
make -C e2e daemonset-lvmd/test
make -C e2e daemonset-lvmd/clean
```
