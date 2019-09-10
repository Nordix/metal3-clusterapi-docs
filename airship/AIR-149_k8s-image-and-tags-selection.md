[main page](README.md)|[experiments](experiments/AIR-149_.md)

---

# Override k8s image registry and tag

**Key objectives**: configure what registry and tag to use for kubernetes control plane components.

Jira Issues:
- [Override K8s registry and tag](https://airship.atlassian.net/browse/AIR-149)

We would like to control which registry or/and tag are used when running kubeadm init and join. 
We can specify both options as described below.

**Configuration file:**
The **tag** and **registry** information can set in kubeadm configuration file. 

```
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns:
  type: CoreDNS
etcd:
  local:
    dataDir: /var/lib/etcd
kind: ClusterConfiguration
imageRepository: k8s.gcr.io v1.14.0 # <----------
kubernetesVersion: v1.14.0          # <----------
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
scheduler: {}

```

**Notes:**

- It is possible to set the regisry. However, the tag remains the same as the kubernetes version.
- Although it is is possible to specify different registry:tag for each control plane component, we do not use any use case for it. Therefore, if one specifies a registry:tag, then that applies for all control plane components.
