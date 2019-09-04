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

The original meeting points can found in Gaps section here: [Airship_F2f_Notes](https://etherpad.openstack.org/p/Airship_F2f_Notes)

## HA options

### Keepalived
- Each node will have its own ip and one common IP among them which is static.
- The common IP (VIP) and each VM’s IP can be used in certificates
- Each joining node can join the “keepalived group” much like the original nodes then configures kubeadm to use the VIP as a cluster IP. 
- Node removal does not cause total failure of the cluster, but downtime if the node had the VIP

### BGP VIP with Calico
As we know it now, both BGP and Calico components run inside kubernetes. And, those components that run each node (controllers, workers) run as pods. Given these issues, we do not have an answer for the following

- Kubeadm does not get any relevant static information from BGP and Calico as they are setup after the cluster is created.
- Once there is a cluster, then BGP-Calico setup can be done regardless of how the cluster was created

### External Load Balancers

An external Load balancer is a component that resides outside of a kubernetes cluster such that
- It a static address that can be used in creating certificates
- Before adding a control plane node, the LB needs to be configured to route traffic to the new node
- A new control plane can join dynamically but can NOT be used unless an entry is created in the LB for it.
- A removal of a control plane node can cause issues unless the corresponding entry is removed from the LB before the removal starts

### HA proxy in each machine
This does NOT require an existing kubernetes cluster, But there are two issues that need to be considered. 
- The setup does not serve external users as a single entry point or else we need one more external LB abstracting them.
- There are more LBs to keep in sync with

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


# To do Items
- Verify that sha256 can be used to do docker operations. [Jira](https://airship.atlassian.net/browse/AIR-147)
- investigate setting pause containers image before manifest file generation.[Jira](https://airship.atlassian.net/browse/AIR-148)
- investigate a way to add image tags before manifest files are generated. [Jira](https://airship.atlassian.net/browse/AIR-149)