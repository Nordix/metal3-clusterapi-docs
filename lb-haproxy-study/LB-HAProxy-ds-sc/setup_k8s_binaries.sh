#!/bin/bash

# The following is run on all vms (both masters and nodes)
sudo yum update -y
sudo yum install -y tree vim net-tools wget nmap

# Install apache for testing external access
#sudo yum install -y httpd
#sudo systemctl start httpd
#sudo systemctl enable httpd
#sudo systemctl status httpd

# Install docker
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl status docker

# add user to docker group | not effective immediately
usermod -aG docker vagrant #or any user you have


cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

# Set SELinux in permissive mode and update configuration file
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config


#Install kubeadm, kubelet and kubectl
yum install -y kubelet-1.16.3-0 kubeadm-1.16.3-0 kubectl-1.16.3-0 --disableexcludes=kubernetes
systemctl enable kubelet
systemctl start kubelet
systemctl status kubelet

# Make sure iptables is not bypassed
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# Configure cgroup driver on each vm
echo KUBELET_KUBEADM_EXTRA_ARGS=--cgroup-driver=cgroupfs --hostname-override > /etc/default/kubelet

#Restart kubelet:
swapoff -a
systemctl daemon-reload
systemctl restart kubelet

