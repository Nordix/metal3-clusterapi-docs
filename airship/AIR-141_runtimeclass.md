[main page](README.md)|[experiments](AIR-141_.md)

---

# RunTimeClass configuration

**Key objectives**: Enabling configuring different run times for all nodes in a cluster.

Jira issues:
- [RunTimeClass configuration](https://airship.atlassian.net/browse/AIR-141)

## RuntimeClass Introduction
It is possible to define RunTimeClass kind configuration to control runtimes used for pods.
See example runtimeclass definition below.
```
apiVersion: node.k8s.io/v1beta1
kind: RuntimeClass
metadata:
  name: containerdruntimeclass
handler: containerd
```
After class is configured, it can be taken into use in pods, see example pod definition below.
```
apiVersion: v1
kind: Pod
metadata:
  name: example
spec:
  runtimeClassName: containerdruntimeclass
  containers:
    - name: dummy-pod
      image: ubuntu
      command: ["/bin/bash", "-ec", "while :; do echo '.'; sleep 5 ; done"]
  restartPolicy: Never
```
## Runtime selection for Kubeadm

Kubeadm detects available runtime sockets and if there is more than one runtime socket available, kubeadm expects
that user will define wanted runtime in Kubeadm config.yaml or by setting --cri-socket parameter:


```
config.yaml:
...
kind: InitConfiguration                  
localAPIEndpoint:                        
  advertiseAddress: 1.2.3.4              
  bindPort: 6443                         
nodeRegistration:                        
  criSocket: /var/run/crio/crio.sock
  name: master1                          
  taints:                                
  - effect: NoSchedule                   
    key: node-role.kubernetes.io/master  
...

kubeadm init --config=config.yaml
```
OR
```
kubeadm init --cri-socket /var/run/crio/crio.sock
```


## Runtime installation
Packages needed for runtime installations can be installed into ISO/qcow2 images.
See example for installation script for CRI-O.


#### CRI-O installation script for (Centos 7)

```
sudo su
modprobe overlay
modprobe br_netfilter
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
cat << EOF > /etc/yum.repos.d/crio.repo
  [cri-o]
    name=CRI-O Packages for EL 7 — $basearch
    baseurl=https://cbs.centos.org/repos/paas7-crio-311-candidate/x86_64/os
    enabled=1
    gpgcheck=0
EOF
yum -y install cri-o cri-tools
systemctl start crio
exit
```
# Summary
External runtime (CRI-O in this case) can be preinstalled to ISO image or can be installed 
in cloud init phase. Selected runtime for the cluster can be selected in Kubeadm init phase.
Runtime classes for pods are not needed in case the whole cluster uses the same runtime.
