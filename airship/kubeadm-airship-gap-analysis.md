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


# To do Items
- Verify that sha256 can be used to do docker operations. [Jira](https://airship.atlassian.net/browse/AIR-147)
- investigate setting pause containers image before manifest file generation.[Jira](https://airship.atlassian.net/browse/AIR-148)
- investigate a way to add image tags before manifest files are generated. [Jira](https://airship.atlassian.net/browse/AIR-149)