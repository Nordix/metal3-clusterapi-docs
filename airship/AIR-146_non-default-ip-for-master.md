[main page](README.md)|[experiments](experiments/AIR-146_.md)

---

# Non-default IP for control plane components

**Key objectives**: configuring api-server and etcd to use a non-default network interface.

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

**Custom kubeconfig-init with:**

Master1: api-server uses IP1 and etcd uses IP2

**Custom kubeconfig-join with:**

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

## Sample Configurations

Init configuration 

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.10.2 # non-default
  bindPort: 6443
nodeRegistration:
  name: kind-control-plane
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/master
---
apiServer:
  timeoutForControlPlane: 30s
apiVersion: kubeadm.k8s.io/v1beta2
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controlPlaneEndpoint: "192.168.10.2:6443"
controllerManager: {}
dns:
  type: CoreDNS
#---------------------Not needed------------------------------#
# Setting etcd to listen on an other non-default interface brings no benefit as the joining master cannot do the same

etcd:
  local:
    dataDir: /var/lib/etcd
    extraArgs:
      initial-cluster-state: new
      name: mycluster1-control-plane
      initial-cluster: mycluster1-control-plane=https://192.168.20.2:2380
      initial-advertise-peer-urls: https://192.168.20.2:2380
      listen-peer-urls: https://192.168.20.2:2380
      advertise-client-urls: https://127.0.0.1:2379,https://192.168.20.2:2379
      listen-client-urls: https://127.0.0.1:2379,https://192.168.20.2:2379
#---------------------------------------------------#
imageRepository: k8s.gcr.io
kind: ClusterConfiguration
kubernetesVersion: v1.15.0
networking:
  dnsDomain: cluster.local
  serviceSubnet: 10.96.0.0/12
scheduler: {}
```

Join configuration

```yaml
apiVersion: kubeadm.k8s.io/v1beta2
kind: JoinConfiguration
nodeRegistration:
  kubeletExtraArgs:
    node-labels: "label=label1"
discovery:
  bootstrapToken:
    apiServerEndpoint: 192.168.10.2:6443 # That of init-master
    token: c9ac23.nhcwh17fwdd5zbko
    unsafeSkipCAVerification: true
    caCertHashes: 
    - sha256:33efb18e8a3158d01314dc526fc896c7f6658d3a3e30b7d73b9b4633330a90b1
  tlsBootstrapToken: c9ac23.nhcwh17fwdd5zbko
controlPlane:
certificateKey: a60bfc726ed405c6fb457220e1486855a50ff107b70ce9a9bc8b170ffcc5ddba
  localAPIEndpoint:
    advertiseAddress: 192.168.10.3 # That of join_master
```
