# Introduction
The purpose of this document is for studying the limitations of kubeadm in accomplishing the tasks done by airship components.
Each task is mapped to a jira issue and focuses on some specific topic as outlined during a face to face meeting. The original meeting points can found in Gaps section here: [Airship_F2f_Notes](https://etherpad.openstack.org/p/Airship_F2f_Notes)

# Load Balancers

Jira Issues: 
- [metallb](https://airship.atlassian.net/browse/AIR-5)
- [keepalived](https://airship.atlassian.net/browse/AIR-140)

## Introduction

There are multiple alternatives for HA setup. Time wise, Some are setup before a kubernetes cluster is created, while other need the target cluster in place. Based on the following criteria, an assessment was done to determine their usability with kubeadm.

1. Can we have static information that can be used in certificates
2. Can we have all required information before creating the cluster
3. Can new control plane nodes join dynamically
4. Can clusters survive control plane node removal

## HA options

### Keepalived
- Each node will have its own ip and one common IP among them which is static.
- The common IP (VIP) and each node’s IP can be used in certificates
- Each joining node can join the “keepalived group” much like the original nodes then configures kubeadm to use the VIP as a cluster IP.
- Node removal does not cause total failure of the cluster, but downtime if the node had the VIP

### BGP VIP with Calico
As we know it now, both BGP and Calico components run inside kubernetes. And, those components that run each node (controllers, workers) run as pods. Given these issues, we do not have an answer for the following

- Kubeadm does not get any relevant static information from BGP and Calico as they are setup after the cluster is created.
- Once there is a cluster, then BGP-Calico setup can be done regardless of how the cluster was created

### External Load Balancers

An external Load balancer is a component that resides outside of a kubernetes cluster such that
- It has a static address that can be used in creating certificates
- Before adding a control plane node, the LB needs to be configured to route traffic to the new node
- A new control plane can join dynamically but can NOT be used unless an entry is created in the LB for it.
- A removal of a control plane node can cause issues unless the corresponding entry is removed from the LB before the removal starts

### HA proxy in each machine
This does NOT require an existing kubernetes cluster, But there are two issues that need to be considered.
- The setup does not serve external users as a single entry point or else we need one more external LB abstracting them.
- There are more LBs to keep in sync with.

Having multiple LBs has its own problem. The certificate we generate should include all nodes IPs. Now suppose the cert is used in admin.conf for running kubectl.
- To which nodes does kubectl point to ?
- What happens when one of the nodes is removed and replaced by a new one ?  (the new node’s IP/hostname is not included in the certificate, which fails mutual authentication between the client and api-server)

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

## Motivation
For this experiment our motivation is to know the answers to the following questions regarding control plane components: 

* How do these components choose which interfaces to use?
* How do we influence the choice during init phase?
* How do we influence the choice during join phase?
* How granular the configuration could be made?

## Experiment Requirements
In a multi interface control plane node, configuring control plane such that

* IP addresses of control plane components are pre-determined
* During init phase, control plane components use distinct IP addresses
* During join phase, control plane components use distinct IP addresses

## Test Cases
* Apply kubeadm init and join with default configurations to check how it populates the different static pod manifest files
* Use a custom kubeadm-init config file where we add only api-server related configurations and check if a different interface for api-server is assigned
* Extend the 2nd test case by adding etcd-server related configurations in kubeadm-init config file and check if different interface for api-server and etcd-server gets assigned.
* In all of the above cases, consider the impact of these configuration using kubeadm-join config file.

## Test Results

### Test case 1: etcd and api-server IP not given
**Setup:** No custom kubeconfig-init nor kubeconfig-join provided

**Desired result:** None

**Init result:** Both etcd and api-server get the default IP on the init master

**Join result:** Both etcd and api-server user the default IP on the joining master

**Observation:** None

### Test case 2: only api-server IP given
**Setup:** Custom kubeconfig-init with only api-server non-default IP

**Desired result:** Both api-server and etcd use the given IP

**Init Result:** both etcd and the api-server got the given non-default IP

**Join Result:** Both etcd and api-server user the default IP on the joining master experiments(as no config provided)

**Observation:** Joining string did not contribute anything in selecting which IPs to use


### Test case 3: etcd is given IP1 and api-server is given IP2
**Setup:** 
* **Custom kubeconfig-init** where we assign etcd with IP1 and api-server with IP2

**Desired result:** api-server and etcd use these distinct IPs

**Init Result:** etcd uses IP1 and api-server uses IP2

**Join Result:** Both etcd and api-server user the default IP on the joining master

**Observation:** On the joining node, the default IP was used for both etcd and api-server, i.e. the joining string did not contribute in IP selection. Therefore, each server makes its own decision in selecting the IPs. 

### Test case 4: etcd and api-server are given distinct IPs in both init and joining control plane nodes 
**Setup:**

* **Custom kubeconfig-init with:**
Master1: api-server uses IP1 and etcd uses IP2
* **Custom kubeconfig-join with:**
Master2: api-server uses IP3  and etcd uses IP4

**Init result:** The api-server and etcd in master1 use IP1 and IP2 respectively

**Join result:** api-server on joining master uses IP3 as expected. However, the etcd on the joining master uses IP1 (which is that of master1)

**Observation:**
On the init side, it is possible to make the etcd and api-server distinct 
On the join side, it is “not possible” to set the etcd IP directly.

## Final Observations
Here we just pinpoint the answers for the questions asked in [Motivation](#Motivation) section:

* How do these components choose which interfaces to use?
    * If no information is given, it takes the default interface
* How do we influence the choice during init phase?
    * By providing relevant ips in kubeconfig file
* How do we influence the choice during join phase?
    * By providing relevant ips in kubeconfig file
* How granular the configuration could be made?
    * Only one IP works. I.e. both the api-server and etcd can have the same non-default IP.
    * Though not likely, if it is desired that the api-server and the etcd use two distinct non-default IPs, then more investigation needs to be done.

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
---
.
.
.
```

Whether to put the flags in the kubeadm or kubelet configuration needs further study. However, the pause image is configurable.

For building a pause container, please refer to [build pause containers](https://github.com/kubernetes/kubernetes/tree/master/build/pause)

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
