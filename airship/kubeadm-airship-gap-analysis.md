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


# Override k8s image registry and tag
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

# To do Items
- Verify that sha256 can be used to do docker operations. [Jira](https://airship.atlassian.net/browse/AIR-147)
- investigate setting pause containers image before manifest file generation.[Jira](https://airship.atlassian.net/browse/AIR-148)