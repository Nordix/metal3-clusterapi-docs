# Meta provider notes

## BYOH provider

The Bring-Your-Own-Host provider was chosen for this test for two reasons:

1. Due to its design (you provision the host yourself), it is very easy to set up the hosts in various ways to accommodate the test (e.g. use a VM in the same network that the metal3-dev-env uses).
2. It was mentioned on slack as one of the providers that works when combining multiple providers for a single cluster.

**The test was successful**: It is possible to combine BYOH and metal3 to create a single cluster.
More details below.

## Test BYOH + Metal3

On a high level this is how it is done:

1. Create a cluster and control plane backed by the BYO provider (but no MachineDeployment).
2. Create a metal3cluster and related resources with control plane endpoint pointing to the BYO control plane.

This is all it takes to make it "work", but of course there are still some weird things.
For example the Cluster only has one infrastructureRef and it is pointing to the BYO provider, as seen here:

```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: byoh-cluster
spec:
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: KubeadmControlPlane
    name: byoh-cluster-control-plane
  # Note: Only a single infrastructureRef is allowed.
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: ByoCluster
    name: byoh-cluster
...
```

### Detailed steps

See the manifests in `BYOH+metal3`.

1. Set up metal3-dev-env on ubuntu and run `make`
2. Add another VM to use as a BYOHost: `vagrant up`
3. Initialize the BYO provider and register the BYO host
   On the management host:
   ```bash
   clusterctl init --infrastructure byoh
   cp ~/.kube/config ~/.kube/management-cluster.conf
   export KIND_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' kind-control-plane)
   sed -i 's/    server\:.*/    server\: https\:\/\/'"$KIND_IP"'\:6443/g' ~/.kube/management-cluster.conf
   scp -i .vagrant/machines/control-plane1/libvirt/private_key /home/ubuntu/.kube/management-cluster.conf vagrant@192.168.10.10:management-cluster.conf
   ```
   On the BYOH:
   ```bash
   sudo apt-get install socat ebtables ethtool conntrack
   wget https://github.com/vmware-tanzu/cluster-api-provider-bringyourownhost/releases/download/v0.2.0/byoh-hostagent-linux-amd64
   mv byoh-hostagent-linux-amd64 byoh-hostagent
   chmod +x byoh-hostagent
   sudo ./byoh-hostagent --kubeconfig management-cluster.conf
   ```
4. Apply BYO manifest to create a cluster with control plane from BYO
   Note: You should do this in the same namespace where the BMHs are!
   ```bash
   kubectl -n metal3 apply -f BYOH+metal3/byoh-components.yaml
   ```
5. Apply the Metal3 manifests to add a MachineDeployment with metal3 as provider.
   Note: You will need to replace the `sshAuthorizedKeys` with your own to get ssh access to the BMHs.
   ```bash
   kubectl -n metal3 apply -f BYOH+metal3/metal3-cluster.yaml
   kubectl -n metal3 apply -f BYOH+metal3/metal3-workers.yaml
   ```

**Result:** The BYOHost is used to create the control plane and the BMHosts are joined to it as workers. 🎉

## Nested provider

This provider was chosen for the test because it runs the control plane as pods in the management cluster, which is desirable to avoid wasting resources on extra machines.
However, there are some concerns about the suitability and usefulness:

- [There is no scheduler](https://github.com/kubernetes-sigs/cluster-api-provider-nested/blob/main/controlplane/nested/api/v1alpha4/nestedcontrolplane_types.go#L36-L47) in the NestedControlPlaneSpec.
  - Instead of scheduler, vcluster uses a "syncer" to [synchronize some resources](https://www.vcluster.com/docs/architecture/synced-resources) between the nested cluster and the "super cluster".
- The Nested provider does not use the KubeadmControlPlane, instead it has a NestedControlPlane.
  - The necessary config for joining is not available.
    There should be a configmap `cluster-info` in the `kube-public` namespace along with RBAC to allow `system:anonymous` access.
- This provider seems to be in early stages of development
  - Only CAPI v1alpha4 is supported.
  - Minimal docs and only one release.
  - Scaling of control plane components is not implemented (but possible via StatefulSets)

**The test was not successful**: Since the nested provider doesn't have its own nodes and doesn't use the KubeadmControlPlane provider, it doesn't provide the necessary resources to join nodes to the cluster.

### Test Nested + Metal3

See the manifests in `nested+metal3`.

1. Setup metal3-dev-env for CAPI v1alpha4 on Ubuntu and run `make`.
2. Initialize the nested provider.
3. Follow the docs for [how to create a nested cluster](https://github.com/kubernetes-sigs/cluster-api-provider-nested/tree/main/docs#set-clustername-in-our-example-we-set-clustername-to-cluster-sample).
4. Set up metallb in the KinD cluster using [this guide](https://kind.sigs.k8s.io/docs/user/loadbalancer/).
5. Change the API server Service of the nested cluster to be of LoadBalancer type
6. Edit the KubeadmConfigTemplate so that it adds the LoadBalancer IP to `/etc/hosts`, e.g. add this to `preKubeadmCommands`:
   ```
   echo "172.18.255.200 cluster-sample-apiserver" >> /etc/hosts
   ```
   You may also want to set a password so you can use `virsh console` to check the status of the VM easily.
7. Apply the metal3 manifests

**Result:** The BMH is provisioned, but the Machine stays in Provisioning since it is unable to join the cluster.
Inspecting the kubelet logs and cloud-init reveals that the reason is that it cannot get the `cluster-info` configmap in order to validate the API server.
The necessary RBAC is not in place, and the configmap is also missing.
However, the Machine was able to reach the control plane, so that is at least something.

It would be possible to add this configmap and RBAC of course, but there would likely be issues also after fixing this.
For example, there is no scheduler in the nested cluster so there is no way to schedule pods on the nodes even if they managed to join.

## Links

- [Nested provider](https://github.com/kubernetes-sigs/cluster-api-provider-nested)
- [vcluster provider](https://github.com/loft-sh/cluster-api-provider-vcluster) - Very similar to the nested provider. Both use vcluster underneath.
- [vcluster](https://www.vcluster.com/)
- [BYOH provider](https://github.com/vmware-tanzu/cluster-api-provider-bringyourownhost)
- [microvm provider](https://github.com/weaveworks-liquidmetal/cluster-api-provider-microvm) - suggested as one of the providers that works for multi provider clusters.
- [Kamaji](https://github.com/clastix/kamaji) - a tool to build and operate a managed kubernetes service with control planes running in the managager cluster. Aims to become a CAPI provider.
- [Slack thread discussing multiple providers for a single cluster](https://kubernetes.slack.com/archives/C8TSNPY4T/p1654074545843379)

## TODO

- Investigate BYO running in the management cluster as a container
- Investigate kamaji
