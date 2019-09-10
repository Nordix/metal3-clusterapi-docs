[main page](README.md)|[experiments](experiments/AIR-148_.md)

---

# Pause container image configuration

**key objectives**: configure what pause image to use before manifest files are generated.

Jira Issues:
- [Pause container selection](https://airship.atlassian.net/browse/AIR-148)


In order to set the registry of pause container, independent of k8s control plane components, one can use the following command line argument. BUt, we do not consider such cases.

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

After kubeadm init runs, the values is set in the following file.
```
root@kind-control-plane:~# cat /var/lib/kubelet/kubeadm-flags.env 

KUBELET_KUBEADM_ARGS="--cgroup-driver=cgroupfs 
--network-plugin=cni 
--pod-infra-container-image=k8s.gcr.io/pause:3.1"
```

Notes:
- We can set the registry for the pause container. However, the tag is hard coded to 3.1 in kubeadm constants.
- The registry is set via the registry of kubernetes control plane components.
- For building a pause container, please refer to [build pause containers](https://github.com/kubernetes/kubernetes/tree/master/build/pause)
