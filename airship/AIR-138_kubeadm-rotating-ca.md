[main page](README.md)|[experiments](experiments/AIR-138_.md)

---

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