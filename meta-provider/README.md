# Meta provider notes

These notes are from an investigation of how to combine cluster API providers so that a single cluster can have multiple providers.
This can be beneficial for example when one provider is "expensive", but required for certain workload, while another is "cheap".
The end goal would be to run the control plane components as pods in the management cluster and join workers to this using the Metal3 provider.

**Key points from this investigation:**

- Metal3 can already be combined with other providers successfully.
  See "Test BYOH + Metal3" below for more details.
- Kamaji is the most promising project for providing the control plane.
- The vcluster and nested providers could also be used but would require modifications and their goals may not align with this use case.

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
   sudo ./byoh-hostagent --namespace metal3 --kubeconfig management-cluster.conf
   ```
4. Apply BYO manifest to create a cluster with control plane from the BYOH provider.
   Note: You should do this in the same namespace where the BMHs are!
   ```bash
   kubectl -n metal3 apply -f BYOH+metal3/byoh-components.yaml
   ```
5. Apply the Metal3 manifests to add a MachineDeployment with metal3 as provider.
   Note: You will need to replace the `sshAuthorizedKeys` with your own to get ssh access to the BMHs.
   ```bash
   kubectl -n metal3 apply -f BYOH+metal3/metal3-cluster.yaml
   kubectl -n metal3 apply -f BYOH+metal3/metal3-workers-ubuntu.yaml
   ```
6. Get the workload cluster kubeconfig and apply Calico as CNI.
   ```bash
   clusterctl get kubeconfig -n metal3 byoh-cluster > kubeconfig.yaml
   export KUBECONFIG=kubeconfig.yaml
   kubectl apply -f https://docs.projectcalico.org/v3.20/manifests/calico.yaml
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

## BYOH as container

Unfortunately I was not able to get this to work *inside the management cluster*.
The getting started guide shows how to do it as a separate container besides a KinD cluster.
My attempt was to use the same container image to create a pod inside the management cluster (KinD/Minikube).
The issues were:

1. **KinD:** Kubeadm init fails when pulling the scheduler image with
   ```
   failed to convert whiteout file \"usr/local/.wh..wh..opq\": operation not supported: unknown
   ```
   This seems to be a common error when using nfs, and I'm guessing the issue comes from how KinD works (Kubernetes in Docker and now we add one more layer to this).
2. **Minikube:** Kubeadm init fails with
   ```
   [ERROR FileContent--proc-sys-net-bridge-bridge-nf-call-iptables]: /proc/sys/net/bridge/bridge-nf-call-iptables does not exist
   ```
   This is probably because the container image used depends on the kernel and there is a mismatch between the kernel minikube is using and what the container image needs.
   (`modprobe br_netfilter` does not help in this case.)
   The problem is that they make an assumption in the Dockerfile that it is running on Ubuntu.

The above issues show that the BYOH provider is not really designed to be run in a container.
It tries to run kubeadm in the container instead of running the control plane components directly as separate containers.
This means that it requires access to the hosts container runtime which is not ideal.
Especially when considering multi tenancy.

## Kamaji

- Has CAPI on the roadmap!
- Multi-tenant etcd in the management cluster. (Pooling and dedicated etcd is on the roadmap.)
- Kubernetes control plane runs as simple deployment (3 containers in the pods, kube-apiserver, kube-scheduler and kube-controller-manager).

AFAIU this is much closer to what we are after than vcluster and the providers based on it.
However, there is *no integration with CAPI* at the moment so it is impossible to join metal3 nodes to it.
The meta provider would in this case consist of a kamaji control plane provider and possibly also an infrastructure provider.

There was a [discussion on Slack](https://kubernetes.slack.com/archives/C03GLTTMWNN/p1655816212161649) about the future of Kamaji.
Based on this it seems like they are serious about keeping it open source and also moving in the direction of shared governance.
However, it is not possible to say for sure what will happen.

The discussion also revealed that they are already investigating and working on a PoC for integrating Kamaji with the cluster API.
The goal of this is to allow Kamaji to provide the control plane that other providers can then join nodes to.

## Investigate effort to make vcluster/nested provider use normal scheduler

Both the vcluster and nested providers depend on the upstream vcluster project.
The vcluster provider is developed by the same company as the upstream vcluster project (Loft labs) whereas the nested provider lives under the kubernetes-sigs organization.
The vcluster provider is closer to the upstream project and seems easier to modify and configure, so I decided to focus on it and the upstream vcluster project.

In the upstream project and the vcluster provider it is [possible to run a normal scheduler](https://www.vcluster.com/docs/architecture/scheduling#separate-vcluster-scheduler).
This however, *requires* syncing nodes into the vcluster.
So the next step would be to get rid of this requirement and disable the syncer completely in order to get a "normal" cluster.

Unfortunately, this is not so simple, as the syncer is what makes vcluster vcluster.
Instead of the syncer we would need to add the logic that handles joining of nodes (e.g. RBAC rules and other config) and possibly replicate some of the logic that is now baked into the syncer.

The hardest part may not be the technical implementation though.
Convincing the maintainers of vcluster that it should be possible to run it without the syncer just as a "normal" cluster may be harder.

Below are some notes from the attempt to run with scheduler and without syncer.

See the manifests in `vcluster`.

- Based on these [instructions](https://github.com/loft-sh/cluster-api-provider-vcluster#installation-instructions)
- Create a kind cluster.
- Configure clusterctl and initialize vcsluter provider
  ```bash
  mkdir ~/.cluster-api
  cat <<EOF > ~/.cluster-api/clusterctl.yaml
  providers:
  - name: vcluster
    url: https://github.com/loft-sh/cluster-api-provider-vcluster/releases/latest/infrastructure-components.yaml
    type: InfrastructureProvider
  EOF
  clusterctl init --infrastructure vcluster
  ```
- Create a vcluster based on k8s (not k3s) with enabled scheduler and disabled syncer.
  ```bash
  kubectl create ns vcluster
  kubectl apply -f vcluster/vcluster.yaml
  ```
- Get kubeconfig
  ```bash
  kubeconfig -n vcluster get secrets vcluster-certs -o jsonpath="{.data.admin\.conf}" | base64 -d > kubeconfig.yaml
  ```
- Disabling the syncer causes the kubeconfig to not be created in the management cluster.
  But it can be extracted from the container (k3s) or from the vcluster-certs secret (k8s).
- k8s:
  - Manually remove the syncer deployment (named `vcluster`). It is not possible to remove with helm values.
  - Edit the scheduler command to remove `--port=0`.
  - The cluster-info configmap is missing

**Conclusion:** The necessary changes to support our use case would be to
- Add the code in vcluster (not the provider) to allow joining nodes with kubeadm.
  This would require generating some RBAC, a configmap with certificate info and a way to generate tokens at minimum.
- Modify vcluster and the provider (nested or vcluster) to allow disabling the syncer and enabling scheduler *without syncing nodes*.
- Add a way to configure how the vcluster is exposed so that the nodes can communicate with the API server.

### Know issues

- The vcluster provider keeps the `cluster` in provisioning state because of the following:
  ```
  Waiting for the first control plane machine to have its status.nodeRef set
  ```
  Since there are no nodes, there is never a nodeRef.
- When the syncer is disabled, the kubeconfig secret is never created in the management cluster.

## Links

- [Nested provider](https://github.com/kubernetes-sigs/cluster-api-provider-nested)
- [vcluster provider](https://github.com/loft-sh/cluster-api-provider-vcluster) - Very similar to the nested provider. Both use vcluster underneath.
- [vcluster](https://www.vcluster.com/)
- [BYOH provider](https://github.com/vmware-tanzu/cluster-api-provider-bringyourownhost)
- [microvm provider](https://github.com/weaveworks-liquidmetal/cluster-api-provider-microvm) - suggested as one of the providers that works for multi provider clusters.
- [Kamaji](https://github.com/clastix/kamaji) - a tool to build and operate a managed kubernetes service with control planes running in the managager cluster. Aims to become a CAPI provider.
- [Slack thread discussing multiple providers for a single cluster](https://kubernetes.slack.com/archives/C8TSNPY4T/p1654074545843379)
- [Slack discussion about Kamaji future](https://kubernetes.slack.com/archives/C03GLTTMWNN/p1655816212161649)
