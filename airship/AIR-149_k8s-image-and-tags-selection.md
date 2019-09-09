[main page](README.md)|[experiments](experiments/AIR-149_.md)

---

# Override k8s image registry and tag

**Key objectives**: configure what registry and tag to use for kubernetes control plane components.

Jira Issues:
- [Override K8s registry and tag](https://airship.atlassian.net/browse/AIR-149)

We would like to control which registry or/and tag are used when running kubeadm init and join. 
We can specify both options as described in the following two resources.

**Configuration file:**
The **tag** information can set in kubeadm configuration file. 

```
apiServer:
  certSANs:
  - localhost
apiVersion: kubeadm.k8s.io/v1beta2
clusterName: kind
controllerManager:
  extraArgs:
    enable-hostpath-provisioner: "true"
kind: ClusterConfiguration
kubernetesVersion: v1.15.1 <----
metadata:
  name: config
name: config
networking:
  podSubnet: 192.168.0.0/16
```

Both **tag** and **registry** can be overridden on the command line as described here

**Command line:**
As described in [kubeadm init phase control-plane](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init-phase/#cmd-phase-control-plane), we can specify the image for all or part of the control plane components. 


**Notes:**

Although it is is possible to specify different registry:tag for each control plane component, we do not use any use case for it. Therefore, if one specifies a registry:tag, then that applies for all control plane components.