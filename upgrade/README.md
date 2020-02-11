# e2e upgrade 

## Introduction

## Manual upgrade

## Use cases
### Upgrade kubeadm, kubelet and kubectl
https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

* Example cluster running on top of CentOS with loadbalancer, master1, 2 and 3
* current k8s version
```sh
  kubectl get nodes -o wide
```
* available upgrade to version
```sh
  yum list --showduplicates kubeadm --disableexcludes=kubernetes
```
* master1, 2 and 3:
```sh
  sudo yum update -y
  sudo yum install -y kubeadm-1.1X.X --disableexcludes=kubernetes
  sudo kubeadm version
```
* master1:
```sh
  sudo kubeadm upgrade plan
  sudo kubeadm upgrade apply 1.1X.X
```
* master2 and 3:
```sh
  sudo kubeadm upgrade node
```
* master1, 2 and 3:
```sh
  sudo yum install -y kubelet-1.1X.X kubectl-1.1X.X --disableexcludes=kubernetes
  sudo systemctl daemon-reload
  sudo systemctl restart kubelet
```
## 

## References
