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
### Add/replace nodes to an existing cluster
https://kubernetes.io/docs/setup/release/version-skew-policy/#supported-version-skew
Kubeadm upgrade is not used in this case. Add/replace should be supported between Kubernetes minor versions, e.g 1.16 to 1.17.
* setup a cluster running e.g 3 nodes
  * certificate-key can be found in config used in kubeadm init, e.g kubeadm-config.yaml
* check cluster content and component versions
```sh
  kubectl get nodes
  kubeadm version
  kubelet --version
  kubectl version
```
* create new node(s) and join to cluster
```sh
  TOKEN=$(kubeadm token generate)
  JOIN_WORKER=$(sudo kubeadm token create ${TOKEN} --print-join-command)
  JOIN_MASTER="${JOIN_WORKER} --control-plane --certificate-key ${KEY}"
  sudo ${JOIN_MASTER}
  sudo ${JOIN_WORKER}
```
* clean up "old" nodes
```sh
  sudo kubeadm reset -f || true
```
* the cluster leader might be re-elected
```sh
  kubectl describe endpoints kube-scheduler -n kube-system
```

## 

## References
