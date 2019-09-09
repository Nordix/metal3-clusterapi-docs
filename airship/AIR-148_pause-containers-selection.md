[main page](README.md)|[experiments](experiments/AIR-148_.md)

---

# Pause container image configuration

**key objectives**: configure what pause image to use before manifest files are generated.

Jira Issues:
- [Pause container selection](https://airship.atlassian.net/browse/AIR-148)


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
---
.
.
.
```

Whether to put the flags in the kubeadm or kubelet configuration needs further study. However, the pause image is configurable.

For building a pause container, please refer to [build pause containers](https://github.com/kubernetes/kubernetes/tree/master/build/pause)