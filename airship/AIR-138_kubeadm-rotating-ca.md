[main page](README.md)|[experiments](experiments/AIR-138_.md)

---

# CA rotation with kubeadm
**Key objectives**: 
Investigate certificate renewal and CA rotation capabilities of Kubeadm. 

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

The validity of the certificates can be set while generating certificate signing requests (CSRs). 

In Kubeadm there are options to renew/rotate certificates automatically and manually. 

### Automatic Certificate Renewal 
Kubadm does automatic renewal of all certificates during control plane upgrade. Our experiment findings with this use case is as follows:
1. Test case: Upgrading cluster from version: 1.14.0 to 1.15.0
    During the upgrade process kubeadm renews the following certificates:

```
apiserver-etcd-client.crt
apiserver-kubelet-client.crt
apiserver.crt
front-proxy-client.crt
Certificates in:
    admin.conf
    controller-manager.conf
    scheduler.conf
```
Following certificates are not renewed:

```
ca.crt
front-proxy-ca.crt
ca.crt
etcd:-
    ca.crt
    healthcheck-client.crt
    peer.crt
    server.crt
Certificates in:
    kubelet.conf
```
3. There is no downtime in accessing user workload service.

### Manual Certificate Renewal

The manual certificate renewal/rotation is performed as described in previous comments. The ```renew``` command in alpha phase allows renewing the following certificates

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
The same set of observations apply here as stated in [Automatic Certificate Renewal](###Automatic%20Certificate%20Renewal) 

## Key observations
1. Only client certificate is renewed. 
2. Even if the CA certificate is soon expiring kubeadm does not renew it automatically. CA rotation has to be done manually.
3. During the client certificate renewals there is no downtime in service.
4. The whole process of CA rotation need more experiments to conclude on service downtime.

## Note 
A new component [kubernetes operator](https://github.com/kubernetes/kubeadm/issues/1698) is proposed to control configuration changes, and upgrades in a systematic fashion. It will possibly include a few of the concerns mentioned here i.e. enable support for cluster lifecycle activities like certificate rotation, client certificate renewal and other related activities in kubeadm. It would be important to keep an eye on these activities and suggest relevant changes required for airship.
