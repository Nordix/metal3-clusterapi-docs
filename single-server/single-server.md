# Single Server Study

This is a POC study following the [Single Server Deployment Study](https://docs.google.com/document/d/1Fgiz-TRBn4L4Ur00j-v7TcloL6v6L86Xc4IbFr3Qde4/edit?ts=5e86e740#heading=h.adzuc1cjggcf) made in April, 2020. Purpose of this study is to find out what are the steps to restore cluster status after OS upgrade in single server deployment.

K8s cluster for the testing is generated using `kubeadm` tool and does not include any **CAPM3**, **CAPI** or **METAL3-DEV-ENV** related components or workflows.

## Backup the data

To be able to initialize a new cluster after upgrading with the old state, we need to backup following data items.

* The root certificate files `/etc/kubernetes/pki/ca.crt` and `/etc/kubernetes/pki/ca.key`.
* The etcd data.

We enable etcd backup by mounting extra disk to etcd's default [--data-dir](https://etcd.io/docs/v3.4/op-guide/configuration/#--data-dir) `/var/lib/etcd` before running `kubeadm init`. Backing up the root certificate is a one-time operation that is done manually after creating the master with kubeadm init. We copied `/etc/kubernetes/pki/ca.crt` and `/etc/kubernetes/pki/ca.key` to extra disks.

## Manual steps to preserve cluster data

1. Create VM with two bootable disks. **Note:** We actually used the same disk image to create these disks.

2. Add new "data" disk to VM. We took following steps after disk creation:

    ```bash
    sudo (echo n; echo p; echo 1; echo  ;echo  ;echo w) | fdisk /dev/<device_name>
    sudo mkfs.ext4 /dev/<device_name>
    mkdir var/lib/etcd
    sudo mount /dev/<device_name> /var/lib/etcd
    ```

3. Install kubeadm and set up the environment:

    1. These instructions was used to install `kubeadm` [Installing kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/)
    2. Set `/proc/sys/net/ipv4/ip_forward` content to `1`

4. Run kubeadm init `sudo kubeadm init --ignore-preflight-errors=DirAvailable--var-lib-etcd`. Always use `--ignore-preflight-errors=DirAvailable--var-lib-etcd` flag with kubeadm init. Otherwise initialization will fail, if previously mounted disk's file system has any content. For example in case of ext4 `lost+found` folder is created during `sudo mkfs.ext4 /dev/<device_name>`.

5. Install Calico `kubectl apply -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml`

6. Remove taint from controlplane `kubectl taint nodes --all node-role.kubernetes.io/master-`. We remove taint from our controlplane to be able to add some resources.

7. Create new resources.

    ```bash
    kubectl create ns test-ns
    kubectl run test-pod --image=nginx -n test-ns
    ```

8. Boot host from second disk.

9. Redo steps 3. (Install kubeadm and set up the environment).

10. Remount the data disk and restore cert.

    1. Create `/etc/kubernetes/pki/` and `/var/lib/etcd` folders
    2. Remount disk `sudo mount /dev/<device_name> /var/lib/etcd`
    3. Move or copy ca.crt and ca.key from "data" disk to `/etc/kubernetes/pki/`

11. Rerun kubeadm init `sudo kubeadm init --ignore-preflight-errors=DirAvailable--var-lib-etcd`

If you have followed these steps you should see all resources like `calico` and `test-pod` pods running in your cluster after `kubeadm init`. When using restored `ca.crt` and `ca.key` your `kubeadm join --discovery-token-ca-cert-hash` should be unchanged.

## Notes for further testing and development

### ETCD snapshots

* `etcdctl` tool gives us the ability to take etcd snapshots. Snapshots can be used for [disaster recovery](https://etcd.io/docs/next/op-guide/recovery/#restoring-a-cluster) and recreation of etcd member after the upgrade.
* It would be ideal to take etcd snapshots regularly using for example [cron job](https://labs.consol.de/kubernetes/2018/05/25/kubeadm-backup.html). Maybe we can test, if snapshots could be used for rollback the cluster state?

**Note:** Would it be possible to run a side-car container within etcd pod for taking snapshots? For testing this, we might need to run [kubeadm init in phases](https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-init/#init-phases).

### Disk backup

How to recover if "data" disk fails?

### Use CAPI for single server deployment

* As an end goal, we might want to be able to use CAPI to deploy our single server cluster, scale it up to HA cluster and vice versa.
* To be able to use CAPI for upgrade, it should support in-place upgrade first.
