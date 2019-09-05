# Introduction
The purpose of this document is for studying the limitations of kubeadm in accomplishing the tasks done by airship components.
Each task is mapped to a jira issue and focuses on some specific topic as outlined during a face to face meeting. The original meeting points can found in Gaps section here: [Airship_F2f_Notes](https://etherpad.openstack.org/p/Airship_F2f_Notes)
 

# Load Balancers

Jira Issues: 
- [metallb](https://airship.atlassian.net/browse/AIR-5)
- [keepalived](https://airship.atlassian.net/browse/AIR-140)

# CA rotation with kubeadm
Jira Issues:
- [CA rotation](https://airship.atlassian.net/browse/AIR-138)

# Providing more certificates and encryption key
Jira Issues:
- [Providing more certificates](https://airship.atlassian.net/browse/AIR-142)

# RunTimeClass configuration
Jira issues:
- [RunTimeClass configuration](https://airship.atlassian.net/browse/AIR-141)

# Non-default IP for control plane components
Jira issues:
- [Non-default IP for control plane components](https://airship.atlassian.net/browse/AIR-146)

# Pause container image configuration

Jira Issues:
- [Pause container selection](https://airship.atlassian.net/browse/AIR-148)

**Summary:**

Question: Can we set specific pause image before static pod manifest generation.
Answer: Yes


The ```--pod-infra-container-image``` can be used to set specific pause container image.


The output shown below is from a running kubelet.

```bash
root@kind-control-plane:~# pstree $(pgrep kubelet) -al

kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf \
--kubeconfig=/etc/kubernetes/kubelet.conf \
--config=/var/lib/kubelet/config.yaml \
--cgroup-driver=cgroupfs \
--network-plugin=cni \
--pod-infra-container-image=k8s.gcr.io/pause:3.1 \
--fail-swap-on=false
.
.
.
```
Also relevant is the following
```
root@kind-control-plane:~# cat /var/lib/kubelet/kubeadm-flags.env 

KUBELET_KUBEADM_ARGS="--cgroup-driver=cgroupfs 
--network-plugin=cni 
--pod-infra-container-image=k8s.gcr.io/pause:3.1"
```

Kubeadm have some default values for both init and join processes. However, there does not seem to be any flag related to the pause container. 

A similar information can be found in ```/var/lib/kubelet/config.yaml```

```bash
root@kind-control-plane:~# kubeadm config print init-defaults --component-configs 
KubeletConfiguration
apiVersion: kubeadm.k8s.io/v1beta2
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 1.2.3.4
  bindPort: 6443
nodeRegistration:
  criSocket: /var/run/dockershim.sock
  name: kind-control-plane
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
.
.
.
```

Weather to put the flags in the kubeadm or kubelet configuration needs further study. However, the pause image is configurable.

For building a pause container, please refer to [build puause containers]

# To do Items
- Verify that sha256 can be used to do docker operations. [Jira](https://airship.atlassian.net/browse/AIR-147)

- investigate a way to add image tags before manifest files are generated. [Jira](https://airship.atlassian.net/browse/AIR-149)