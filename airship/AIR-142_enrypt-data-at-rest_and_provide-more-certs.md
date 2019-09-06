[main page](README.md)|[experiments](experiments/AIR-142_.md)

---

 
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
