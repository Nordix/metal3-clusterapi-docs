# Single Server Study

This is hand-on POC study following the [Single Server Deployment Study](https://docs.google.com/document/d/1Fgiz-TRBn4L4Ur00j-v7TcloL6v6L86Xc4IbFr3Qde4/edit?ts=5e86e740#heading=h.adzuc1cjggcf) made in April, 2020.Purpose of this study is to find out what are the steps to preserve cluster status after OS upgrade in single server deployment.

Single server deployment in this case meaning single VM hosting single control plane K8s cluster. Our K8s cluster is generated using ```kubeadm``` tool and does not include any **CAPM3**, **CAPI** or **METAL3-DEV-ENV** related components or workflows.

### Backup the data

For initializing a new cluster with preserved status after upgrade, we need to backup following data items.  
* The root certificate files ```/etc/kubernetes/pki/ca.crt``` and ```/etc/kubernetes/pki/ca.key```.
* The etcd data.

We enable etcd back up by mounting extra disk to etcd's default [--data-dir](https://etcd.io/docs/v3.4/op-guide/configuration/#--data-dir) /var/lib/etcd before running ```kubeadm init```. Backing up the root certificate is a one-time operation that is done manually after creating the master with kubeadm init. We copied ```/etc/kubernetes/pki/ca.crt``` and ```/etc/kubernetes/pki/ca.key``` to our extra disks root. 