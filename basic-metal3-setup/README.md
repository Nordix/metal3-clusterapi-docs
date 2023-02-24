# Basic Metal3 setup

The goal here is to create a PoC for a simpler, more basic version of metal3-dev-env.
It should be possible to provision a workload cluster, but pivoting is out of scope.

The BareMetalHosts are backed by libvirt VMs just like in metal3-dev-env and VBMC is used as BMC.
Minikube with the kvm2 driver was chosen as bootstrap cluster since this gives a very simple network layout.
All BMHs are created in the same libvirt network that minikube uses.

VBMC is deployed in minikube as a container using the host network.
This makes it easy for Ironic to communicate with it.
(Ironic also runs in the host network, so using the internal cluster network would be challenging.)
VBMC communicates with libvirt over ssh to the host machine (similar to metal3-dev-env).

Libvirt comes with its own dnsmasq instance.
This is used for DHCP and PXE, which means we can completely remove dnsmasq from Ironic.
One complication here, that should be solved in a better way, is how PXE boot is configured.
The boot files are hosted by the Ironic httpd container, which uses the minikube IP.
But this IP is not known until minikube has been started.
Luckily, it is persistent between minikube restarts, so we simply have to start minikube first to check the IP and then configure libvirts dnsmasq to point to it (and restart the network and minikube to pick up the changes).

The image server ("httpd-infra") is run as a simple container on the host.

Folders and files:

- baremetal-operator: kustomization for deploying BMO (copied from the BMO repo and adapted)
- ironic: kustomization for deploying Ironic (copied from the BMO repo and adapted)
- haproxy: kustomization for haproxy, used as loadbalancer for the control plane
- scripts: scripts used for provisioning the nodes (injected using cloud-init)
- ipam: kustomization for patching the cluster template and adding an IPPool with a single IP used by the control plane
- ipam-ha: kustomization for patchin the cluster template and adding an IPPool with multiple IPs to be fronted by HAProxy
- bmh.yaml: template for creating BMHs
- create_bmh.sh: script for creating libvirt-backed BMHs
- delete_bmh.sh: script for deleting libvirt-backed BMHs
- vbmc.yaml: VBMC deployment

Note: The script snippets below are not guaranteed to work if you paste all in one go.
Do one command at a time and check the results in between.
Some of these take time.

## Prerequisites

For this to work, you will need at least the following:

- libvirt
- virt-install (`sudo apt install virtinst`)
- sshd (for VBMC to access libvirt on the host from minikube)
- [minikube](https://minikube.sigs.k8s.io/docs/start/) with the [KVM driver](https://minikube.sigs.k8s.io/docs/drivers/kvm2/)
- [docker](https://docs.docker.com/engine/install/) (or podman, but docker is used in the code snippets)
- [clusterctl](https://cluster-api.sigs.k8s.io/user/quick-start.html#install-clusterctl)
- [kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)

## Setup minikube with vbmc and the Metal3 stack

```bash
## Minikube setup with libvirt and PXE boot
minikube start --driver=kvm2
# Get the IP address of minikube in the default network
# This is the IP address of the interface of the default network (where the BMHs are).
MINIKUBE_ETH1_IP="$(minikube ssh -- ip -f inet addr show eth1 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')"
minikube stop
# Edit the network to have <bootp file=http://MINIKUBE_ETH1_IP:6180/boot.ipxe/> (under network.ip.dhcp)
# <network connections='2'>
#   <name>default</name>
#   ...
#   <ip address='192.168.122.1' netmask='255.255.255.0'>
#     <dhcp>
#       <range start='192.168.122.2' end='192.168.122.254'/>
#       <bootp file='http://MINIKUBE_ETH1_IP:6180/boot.ipxe'/>
#     </dhcp>
#   </ip>
# </network>
virsh net-destroy default
echo "Add this to the network:"
echo "<bootp file='http://${MINIKUBE_ETH1_IP}:6180/boot.ipxe'/>"
virsh net-edit default
virsh net-start default
# Start minikube again
minikube start

## VBMC with ssh connection to libvirt on the host
# TODO: Ensure host has sshd running
minikube ssh -- ssh-keygen -t ed25519 -f /home/docker/.ssh/id_ed25519 -N "''"
PUBLIC_KEY="$(minikube ssh -- cat .ssh/id_ed25519.pub)"
echo "${PUBLIC_KEY}" >> ~/.ssh/authorized_keys
kubectl apply -f vbmc.yaml

## Initialize Metal3
clusterctl init --infrastructure metal3
# Set correct IP (eth1) in configmaps and certificates and deploy Ironic and BMO
kustomize build ironic/overlays/basic-auth_tls | sed "s/MINIKUBE_IP/${MINIKUBE_ETH1_IP}/g" | kubectl apply -f -
kustomize build baremetal-operator/overlays/basic-auth_tls | sed "s/MINIKUBE_IP/${MINIKUBE_ETH1_IP}/g" | kubectl apply -f -

## Setup image server
# Download Ubuntu cloud image
mkdir images
pushd images
wget -O MD5SUMS https://cloud-images.ubuntu.com/jammy/current/MD5SUMS
wget -O jammy-server-cloudimg-amd64.vmdk https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.vmdk
md5sum --check --ignore-missing MD5SUMS
MD5SUM="$(grep "jammy-server-cloudimg-amd64.vmdk" MD5SUMS | cut -d ' ' -f 1)"
popd

# Run image server
docker run --rm --name image-server -d -p 80:8080 -v "$(pwd)/images:/usr/share/nginx/html" nginxinc/nginx-unprivileged

# TODO:
# - Persistent cache for Ironic. Mount from host to minikube to container?
#   - Seems like it is not possible to use a folder mounted with `minikube mount`.
#   - Currently just mounting /opt/minikube from the minikube VM in the ironic container.
```

## Adding libvirt backed BareMetalHosts

```bash
## Create BMH backed by libvirt VM
./create_bmh.sh <name> <vbmc_port>

# Example
./create_bmh.sh host-0 16230
./create_bmh.sh host-1 16231
# After this you should see the bmhs go through registering, inspecting and become available
# ❯ kubectl get bmh
# NAME     STATE       CONSUMER   ONLINE   ERROR   AGE
# host-0   available              true             58m
# host-1   available              true             41m

# You can also reserve an IP for the VM.
# This MUST be in the DHCP range of the network.
./create_bmh.sh <name> <vbmc_port> <reserved_ip>

# Example:
./create_bmh.sh host-0 16230 192.168.122.199
```

## Provisioning a BareMetalHost

If you want to use BMO directly (not CAPI + CAPM3), read on.
Otherwise skip to the next section.

```bash
# Create user-data
# It should be a secret with data.value and data.format.
# data.format=cloud-config
# data.value is the cloud config content
cat <<'EOF' > user-data.yaml
#cloud-config
users:
  - name: ubuntu
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: /bin/bash
    lock_passwd: false
    # generate with mkpasswd --method=SHA-512 --rounds=4096
    # nerdvendor
    passwd: $6$rounds=4096$EhcyaSgedVn6D9Qm$WTqrBEESsX6Qe0huYzEy0i13xEfLecPGGB184HvkiFm4SNxLq3WeVE0AA4.hWQz8CXkxqb7J05I6DErQ6qvvi1
EOF
kubectl create secret generic user-data --from-file=value=user-data.yaml --from-literal=format=cloud-config

# Get server IP from BMH point of view
SERVER_IP="$(virsh net-dumpxml default | sed -En "s/.*ip address='([0-9.]+)'.*/\1/p")"

# Test provisioning a BMH
kubectl patch bmh host-0 --type=merge --patch-file=/dev/stdin <<EOF
spec:
  image:
    url: "http://${SERVER_IP}/jammy-server-cloudimg-amd64.vmdk"
    checksum: "${MD5SUM}"
    format: vmdk
  userData:
    name: user-data
    namespace: default
EOF

echo "Wait for it to provision. After this you should be able to login to the console in virt-manager"
echo "using username 'ubuntu' and password 'nerdvendor'."
```

## Creating a workload cluster

Before creating a cluster, we need to decide on how to handle the API endpoint.
It must be known before creating the cluster so we cannot rely on DHCP for it.
For a cluster with only 1 control plane node, we can set up a static address (either reserve it in the DHCP server or use an IPPool with a single IP address).
However, this also means we cannot upgrade it or scale the control plane.

For a more advanced scenario we need a proper loadbalancer or some kind of VIP that can be moved between the nodes.
In metal3-dev-env, we make use of keepalived to get a VIP solution.
This has the drawback that it is quite hard to debug and not very transparent to the user/developer since it runs directly on the relevant nodes.
If it fails for some reason, there is no central overview for the status of the nodes, instead each of them has to be inspected before it is even possible to tell which one was active.

A loadbalancer like HAProxy can be combined with an IPPool with a limited number of addresses so that it only forwards connections to the healthy (in-use) addresses.
It provides a dashboard that can tell the status of each address in the pool and it can be deployed outside of the cluster to keep concerns separated.

Below you will find 3 sections each describing one of the scenarios presented above.
All of them require a template and some variables to be set so to avoid repetition, the common variables and commands are listed here
This snippet may look intimidating, but fear not, most of it is just for installing the necessary packages on the nodes.
For a proper setup it makes more sense to build an image that includes these things but here we are after simplicity and transparency.
This is *all* it takes to get a plain cloud image to work.

NOTE: This will try to inject a public ssh key (`~/.ssh/id_ed25519.pub`) into the VMs.
It is not necessary for anything other than debugging.
If you don't have this public key you can easily generate it (with `ssh-keygen -t ed25519`) or change it to a different file or just remove the relevant lines all together.

```bash
# Download cluster-template
CLUSTER_TEMPLATE=/tmp/cluster-template.yaml
# https://github.com/metal3-io/cluster-api-provider-metal3/blob/main/examples/clusterctl-templates/clusterctl-cluster.yaml
CLUSTER_TEMPLATE_URL="https://raw.githubusercontent.com/metal3-io/cluster-api-provider-metal3/main/examples/clusterctl-templates/clusterctl-cluster.yaml"
wget -O "${CLUSTER_TEMPLATE}" "${CLUSTER_TEMPLATE_URL}"

# Get server IP from BMH point of view
SERVER_IP="$(virsh net-dumpxml default | sed -En "s/.*ip address='([0-9.]+)'.*/\1/p")"

export CLUSTER_APIENDPOINT_PORT="6443"
export IMAGE_CHECKSUM="${MD5SUM}"
export IMAGE_CHECKSUM_TYPE="md5"
export IMAGE_FORMAT="vmdk"
export IMAGE_URL="http://${SERVER_IP}/jammy-server-cloudimg-amd64.vmdk"
export KUBERNETES_VERSION="v1.26.1"
export CTLPLANE_KUBEADM_EXTRA_CONFIG="
    preKubeadmCommands:
      - /usr/local/bin/install-container-runtime.sh
      - /usr/local/bin/install-kubernetes.sh
    files:
      - path: /usr/local/bin/install-container-runtime.sh
        owner: root:root
        permissions: '0755'
        content: |
$(sed 's/^/          /g' scripts/install-container-runtime.sh)
      - path: /usr/local/bin/install-kubernetes.sh
        owner: root:root
        permissions: '0755'
        content: |
$(sed 's/^/          /g' scripts/install-kubernetes.sh)
      - path: /etc/sysctl.d/99-kubernetes-cri.conf
        owner: root:root
        permissions: '0644'
        content: |
          net.bridge.bridge-nf-call-iptables = 1
          net.ipv4.ip_forward = 1
          net.bridge.bridge-nf-call-ip6tables = 1
      - path: /etc/modules-load.d/k8s.conf
        owner: root:root
        permissions: '0644'
        content: |
          br_netfilter
    users:
      - name: ubuntu
        sudo: 'ALL=(ALL) NOPASSWD:ALL'
        sshAuthorizedKeys:
        - $(cat ~/.ssh/id_ed25519.pub)"
export WORKERS_KUBEADM_EXTRA_CONFIG="
      preKubeadmCommands:
        - /usr/local/bin/install-container-runtime.sh
        - /usr/local/bin/install-kubernetes.sh
      files:
        - path: /usr/local/bin/install-container-runtime.sh
          owner: root:root
          permissions: '0755'
          content: |
$(sed 's/^/            /g' scripts/install-container-runtime.sh)
        - path: /usr/local/bin/install-kubernetes.sh
          owner: root:root
          permissions: '0755'
          content: |
$(sed 's/^/            /g' scripts/install-kubernetes.sh)
        - path: /etc/sysctl.d/99-kubernetes-cri.conf
          owner: root:root
          permissions: '0644'
          content: |
            net.bridge.bridge-nf-call-iptables = 1
            net.ipv4.ip_forward = 1
            net.bridge.bridge-nf-call-ip6tables = 1
        - path: /etc/modules-load.d/k8s.conf
          owner: root:root
          permissions: '0644'
          content: |
            br_netfilter
      users:
        - name: ubuntu
          sudo: 'ALL=(ALL) NOPASSWD:ALL'
          sshAuthorizedKeys:
          - $(cat ~/.ssh/id_ed25519.pub)"
```

### Single KCP - static IP using DHCP server

Here we create a BMH with a reserved IP that we can use as control plane endpoint.
Note that we must ensure that this BMH is used for the control plane since it has the IP.
The easiest solution is to make sure it is the only BMH.
For more advanced scenarios we could use a host selector.
But this requires changes to the cluster-template.

```bash
# Setup minikube with the Metal3 stack and VBMC first (see above)
# Create a BMH with reserved IP
./create_bmh.sh host-0 16230 192.168.122.199

# NOTE: Set the variables from the common section above!
# Set the API endpoint to the reserved IP.
export CLUSTER_APIENDPOINT_HOST="192.168.122.199"

# Render the cluster template and apply
clusterctl generate cluster my-cluster \
  --from "${CLUSTER_TEMPLATE}" \
  --target-namespace default | kubectl apply -f -

# You should now be able to see the BMH go through provisioning and become provisioned.
# The Machine should also become Running and get a provider ID.
# Get the kubeconfig and access the workload cluster
clusterctl get kubeconfig my-cluster > kubeconfig.yaml
kubectl --kubeconfig=kubeconfig.yaml get nodes
# NAME     STATUS   ROLES           AGE   VERSION
# host-0   Ready    control-plane   33m   v1.26.1

# Add a worker
./create_bmh.sh host-1 16231
kubectl scale md my-cluster --replicas=1
```

### Single KCP - static IP from IPPool

In this case, we need to add an IPPool and make some additions to the Metal3DataTemplate.
We start with the same steps as in the previous section, but instead of generating and applying the manifests directly, we will save them and make some changes.

```bash
# Setup minikube with the Metal3 stack and VBMC first (see above)
# Create BMHs
./create_bmh.sh host-0 16230
./create_bmh.sh host-1 16231

# NOTE: Set the variables from the common section above!
# Set the API endpoint to the IP in the IPPool.
export CLUSTER_APIENDPOINT_HOST="192.168.122.200"

# Render the cluster template and save the output
clusterctl generate cluster my-cluster \
  --from "${CLUSTER_TEMPLATE}" \
  --target-namespace default > ipam/my-cluster.yaml

# The folder `ipam` contains a kustomization that adds an IPPool with a single IP address
# (192.168.122.200) and patches the Metal3DataTemplate with the necessary bits to make this work.
# Apply it
kubectl apply -k ipam
```

### HA with HAProxy

```bash
# Setup minikube with the Metal3 stack and VBMC first (see above)
# Create BMHs
./create_bmh.sh host-0 16230
./create_bmh.sh host-1 16231
./create_bmh.sh host-2 16232

# Deploy HAProxy
kubectl apply -k haproxy

# NOTE: Set the variables from the common section above!
# Set the API endpoint to the Minikube IP (where HAProxy runs).
export CLUSTER_APIENDPOINT_HOST="$(minikube ssh -- ip -f inet addr show eth1 | sed -En -e 's/.*inet ([0-9.]+).*/\1/p')"
# Render the cluster template and save the output
clusterctl generate cluster my-cluster \
  --from "${CLUSTER_TEMPLATE}" --control-plane-machine-count=3 \
  --target-namespace default > ipam-ha/my-cluster.yaml

kubectl apply -k ipam-ha

# Check HAProxy dashboard
kubectl -n haproxy port-forward deploy/haproxy 9000
# Now go to http://localhost:9000/stats in your browser and login with admin:admin
```

## Cleanup

```bash
kubectl delete cluster my-cluster

# ./delete_bmh.sh <name>
./delete_bmh.sh host-0
./delete_bmh.sh host-1
./delete_bmh.sh host-2
./delete_bmh.sh host-3

# Stop and remove image server
docker stop image-server
# Cleanup images
rm --recursive images

# Remove minikube ssh key from authorized_keys
PUBLIC_KEY="$(minikube ssh -- cat .ssh/id_ed25519.pub)"
sed -i "\#${PUBLIC_KEY}#d" ~/.ssh/authorized_keys

# Remove minikube
minikube delete
```
