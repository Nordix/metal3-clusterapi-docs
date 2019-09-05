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

 
## Use pre-generated certs and user provided CA

This is possible with Kubeadm. We can provide either CA certs only or we can provide the whole list of certificates in ```/etc/kubernetes/pki```. The certificates can be put in the file system with the proper path using a shell script.  In case we provide CA cert only, kubeadm will generate the other certificates using the CA cert. In the latter case, kubeadm will take the pre-generated certs and avoid generating new ones. The placement of the certs can be done using a script.

In case of CABPK following certificates and keys can be specified by the user:
```
cluster-ca-cert
cluster-ca-key
    
etcd-ca-cert  
etcd-ca-key
    
front-proxy-ca-cert
front-proxy-ca-key

service-account-private-key
service-account-public-key
```

## Rotating CA 

Kubeadm currently has an option to renew the CA certificates manually, based on a new CA certificate placed using the method described in previous comment. It is however an alpha version command - 

```kubeadm alpha certs renew```

Our initial experiments with this command however suggest that it has some bugs.(Test bed: Simple Kinder based cluster with one control plane node and kubeadm version 1.15.1). For example, although we command to renew all the certificates based on the new certificate, the admin.conf does not get updated properly. It is still using the old CA certificate and client certificates. 

In case of HA cluster, the certificate renewal has to be done separately on each control plane node.


## Control over certificate validity and rotation

The validity of the certificates can be set while generating CSRs. 

In Kubeadm there are options to renew/rotate certificate automatically and manually. Kubadm does automatic renewal of all certificates during control plane upgrade (We haven’t checked if it works as expected since we are more focused on manual certificate renewal). The manual certificate renewal/rotation is performed as described in previous comments. The ```renew``` command in alpha phase allows to renew the following certificates

```bash
admin.conf               
apiserver              
apiserver-etcd-client    
apiserver-kubelet-client
controller-manager.conf  
etcd-healthcheck-client  
etcd-peer                
etcd-server              
front-proxy-client      
scheduler.conf
```

## Note 
A new component [kubernetes operator](https://github.com/kubernetes/kubeadm/issues/1698) is proposed to control configuration changes, and upgrades in a systematic fashion. It will possibly include a few of the concerns mentioned here i.e. enable support for cluster lifecycle activities like certificate rotation, client certificate renewal and other related activities in kubeadm. It would be important to keep an eye on these activities and suggest relevant changes required for airship. 

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