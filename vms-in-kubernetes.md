# Running vms in a Kubernetes cluster

Two main options are available : KubeVirt and Virtlet. The first runs the
virtual machines in containers while the second use virtual machines instead of
containers, offering an alternative to docker, containerd, etc. with Libvirt.

# Running VMs in Containers with KubeVirt

The main project in this area is KubeVirt. KubeVirt is a CNCF project initiated
by RedHat. Its goal is to provide a virtualization platform using Kubernetes,
allowing users to run and manage their virtual machines as containers in
Kubernetes.

## Container native virtualization

The core idea in the implementation of the project is to run a libvirtd
hypervisor in a container, allowing to run a VM in this container.

![Kubevirt infrastructure](https://kubernetes.io/images/blog/2018-05-22-getting-to-know-kubevirt/kubevirt-components.png)

Each VM runs in a dedicated pod. In each pod there is a libvirtd daemon, and a
virt-launcher process that is the main process of the pod.

The KubeVirt project is composed of four main elements :

* virt-controller: This is the controller that reconciles the CRs created and
  modified by the users. It is available as a Kubernetes Operator. It will
	create the pods for each vm, find out the node on which the pod was scheduled
	and call virt-handler to create the VM
* virt-handler: It will create the libvirtd domain once the pod has been created
* virt-launcher: It takes care of creating the cgroups and namespaces for the
  vm, start it and monitor it.
* virtctl: a command line tool mainly giving access to serial and graphical
  console, it also allows to easily stop or start the machine, and perform live
	migration

Since the virtual machine runs in a container, it is possible to use all the
normal features of a pod, such as volumes, networks and ports to expose. It even
allows users to run service meshes such as Istio.

KubeVirt has also reimplemented the ReplicaSet feature as
VirtualMachineReplicaSet.

## Networking

KubeVirt maps the pod networking to the VM networking. Hence it is possible to
use any of the CNI, such as Multus, calico or flannel. There three possible
network backends: pod, Multus and Genie. The pod backend is the basic pod
network, the first interface. The Multus backend allows you to define multiple
additional networks, and so does Genie. Each of the network interfaces of the
pod is then mapped to VM interface using one of the following:

* bridge: Connect using a linux bridge
* slirp: Connect using QEMU user networking mode
* sriov: Pass through a SR-IOV PCI device via vfio
* masquerade: Connect using Iptables rules to nat the traffic

Other options can be configured, such as the mac address of the interface on the
VM or the ports forwarded.
Below is an example configuration with Multus and bridge:

```yaml
kind: VM
spec:
  domain:
    devices:
      interfaces:
        - name: red
          bridge: {} # connect through a bridge
  networks:
  - name: red
    multus:
      networkName: red
```

Here is the networking
[documentation](https://kubevirt.io/user-guide/docs/latest/creating-virtual-machines/interfaces-and-networks.html)

## Storage

Similarly, KubeVirt implement the VM storage with a backend. For the mapping of
the backend volume to the VM volume, KubeVirt offers three mechanisms:

* LUN device
* disk
* cdrom

Here is an example for a disk backed by a persistent volume.
```yaml
metadata:
  name: testvmi-disk
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachineInstance
spec:
  domain:
    resources:
      requests:
        memory: 64M
    devices:
      disks:
      - name: mypvcdisk
        # This makes it a disk
        disk:
          # This makes it exposed as /dev/vda, being the only and thus first
          # disk attached to the VM
          bus: virtio
  volumes:
    - name: mypvcdisk
      persistentVolumeClaim:
        claimName: mypvc
```

The possible backend volumes are :

* cloudInitNoCloud: maps a secret as cloud-init disk
* cloudInitConfigDrive: maps a secret as cloud-init config drive
* persistentVolumeClaim: maps a persistent volume Claim (PVC)
* ephemeral: maps a persistent volume as read only, with an ephemeral layer that
  is discarded when the vm is stopped
* containerDisk: allows to store images in a container image registry
* emptyDisk: maps to emptyDir, survives VM reboots, but not VM re-creation
* hostDisk: maps to hostpath to use a disk image present on the host
* dataVolume: like PVC, but automates the creation of the pvc for the user
* configMap: mounts a configmap
* secret: mounts a secret
* serviceAccount: mounts a service account

Some features from libvirt related to IO can also be set and used.

Here is the storage
[documentation](https://kubevirt.io/user-guide/docs/latest/creating-virtual-machines/disks-and-volumes.html)

## Other features

### Hardware emulation

Many of the libvirt options can be configured, such as Huge pages, CPU topology,
input devices, clock, BIOS/UEFI etc.

### Dedicated CPUs

If a node has a CPU manager, KubeVirt can dedicate CPUs for a VM

### Cloud-init

Cloud-init can be used when starting a virtual machine, for example using a
cloudInitNoCloud volume or a cloudInitConfigDrive volume.

### Liveliness and Readiness probe

It is possible to define liveliness and readiness probes when creating the
virtual machine. all common options are available.

### Affinity, anti-affinity and node selector

KubeVirt supports those three feature the same way it is used for pods.

## Requirements and installation

There are some requirements towards the nodes that should have hardware
acceleration and could support huge page support. For multiple interfaces on the
vm, Multus or Genie have to be deployed on the cluster. Otherwise a CNI is
required, for example Calico, Cilium or Flannel.

The installation of KubeVirt is done using a Kubernetes operator and hence is
very simple:

```bash
$ export RELEASE=v0.17.0
# creates KubeVirt operator
$ kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-operator.yaml
# creates KubeVirt KV custom resource
$ kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${RELEASE}/kubevirt-cr.yaml
# wait until all KubeVirt components is up
$ kubectl -n kubevirt wait kv kubevirt --for condition=Available
```

## Custom resources and APIs

The API reference is available [here](https://kubevirt.io/api-reference)

Here is an example CR to create a machine :

```yaml
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachineInstance
metadata:
  name: testvmi-nocloud
spec:
  terminationGracePeriodSeconds: 30
  domain:
    resources:
      requests:
        memory: 1024M
    devices:
      disks:
      - name: containerdisk
        disk:
          bus: virtio
      - name: emptydisk
        disk:
          bus: virtio
      - disk:
          bus: virtio
        name: cloudinitdisk
  volumes:
  - name: containerdisk
    containerDisk:
      image: kubevirt/fedora-cloud-container-disk-demo:latest
  - name: emptydisk
    emptyDisk:
      capacity: "2Gi"
  - name: cloudinitdisk
    cloudInitNoCloud:
      userData: |-
        #cloud-config
        password: fedora
        chpasswd: { expire: False }
```

## Running virtual machines in Kubernetes with Virtlet

Virtlet is a Mirantis project aiming at offering a CRI for VMs, hence replacing
docker or containerd with libvirt in Kubernetes. This is aimed at bringing all
the features of pods to virtual machines, but it also brings the limitations of
pods and is much more cumbersome than the KubeVirt add-on approach. The
Kubernetes cluster needs to be deployed with Virtlet and its CRI proxy that
intercepts the CRI calls and decide whether to forward them to Libvirt or
Docker.

### Architecture

Virtlet consists of the following components:

* Virtlet manager which implements CRI interface for virtualization and image handling
* libvirt instance
* vmwrapper which is responsible for setting up the environment for emulator
* the hypervisor, qemu/kvm

In addition to the above, the CRI proxy provides the possibility to mix
docker and VM based workloads on the same k8s node.

![Virtlet infrastructure](https://docs.virtlet.cloud/dev/img/virtlet.png)

### Features

Most features are pods features. In addition, cloud-init can be specified using
annotations, either directly, or referencing a secret or a configmap.

Most Libvirt related configuration is done through annotations on the pod,
for example the CRI to use, the cloud-init etc.

A VM pod is a plain Kubernetes pod definition with the following conditions
satisfied:

* It has kubernetes.io/target-runtime: virtlet.cloud annotation so it can be
  recognized by CRI Proxy.
* The pod has exactly one container.
* The container's image has virtlet.cloud/ prefix followed by the image name
  which is recognized according to Virtlet's image handling rules and used to
  download the QCOW2 image for the VM.

If you have Virtlet running only on some of the nodes in the cluster,
you also need to specify either nodeSelector or nodeAffinity for the pod to
have it land on a node with Virtlet.


## Kata containers

Kata containers are solving a quite different use-case, hence they are not
applicable here. Kata containers are micro VMs used to run containers, using
container images. The goal is to run containers with a better isolation. It does
not enable a user to run full-fledged VMs.

## RancherVM

RancherVM is a solution close to Virtlet. However, the networking in RancherVM
is restrictive as it bridges the host interfaces and require external IPAM.
There is also a requirement for Debian-based cluster with KVM installed. All
nodes must be in the same L2 network. The VM image must be packaged in a Docker
image.

The sake of simplicity to be able to manage a VM like a container even from the
networking point of view has been detrimental to the solution, as it restricts
VMs to having a single interface in the L2 network that must have an external
DHCP and spread across all cluster nodes. This option is only suitable for very
simple scenarios, due to the networking restrictions and is far from offering
all the features available in KubeVirt. Moreover, it does not seem to be
maintained as the last commit is, as of december 2019, from March 2019.

## Home-made solution

It can be pretty straightforward to create a container running libvirtd and
start virtual machines etc. However, if some flexibility is needed for the
networking and the storage, we would much rather recommend a project such as
KubeVirt that offers a lot of features directly.

## Comparison between KubeVirt and Virtlet

KubeVirt and Virtlet are implemented in drastically different ways. KubeVirt is
a virtual machine management add-on for Kubernetes providing control of VMs as
Kubernetes Custom Resources. Virtlet, on the other hand is a CRI (Container
Runtime Interface) implementation, which means that Kubernetes sees VMs in the
same way it sees Docker containers, and the vms are managed as pods.

Virtlet comes with Mirantis Kubernetes the same way as KubeVirt comes
with Openshift. However, outside of provider specific distribution of
Kubernetes, KubeVirt seems the easiest solution to deploy. KubeVirt can also be
completely undeployed. Virtlet should support it too, but requires more
operations.

Both support very advanced networking setup, including SR-IOV, but Kubevirt
support more storage options. KubeVirt is much simpler to install and requires
less configuration, but it adds additional Kubernetes Custom Resource
Definitions. Virtlet implements pods with Libvirt, hence is more restricted in
what can be done (device hotplug, vm scaling), but benefits from native
replicasets and deployments features. The libvirt features supported in Virtlet
are far less than in KubeVirt, for example there is no live migration.
Virtlet is much more complex than KubeVirt, requires more additional components
and seems to receive far less attention from the community.

## Conclusion

KubeVirt globally offers more features and is simpler to use than Virtlet.
Considering the projects themselves, KubeVirt seems to be much more popular and
is a CNCF project. We would hence rather recommend it over Virtlet or self-made
solutions
