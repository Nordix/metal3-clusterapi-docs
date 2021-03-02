
# Cloud Provider OpenStack

Using cluster-api-provider-openstack (CAPO), one can interact with an Openstack cloud to manage the life cycle of a Kubernetes cluster.

In this document we use the CAPO controllers to provision a kuberenetes cluster in two steps.
1. Create a management Kubernetes cluster
2. Deploy a workload to provision a target Kuberenetes cluster

Issues encountered during the process are also documented.

## Set up a management kubernetes cluster

We need a management kubernetes cluster for hosting the ```capo``` controllers.

```bash
#!/bin/bash

# Delete an existing kind cluster, if any.
kind delete cluster --name kind-capo || true
# Create a new kind cluster
kind create cluster --name kind-capo

# Install clusterctl
pushd /tmp
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v0.3.13/clusterctl-darwin-amd64 \
-o clusterctl
chmod +x ./clusterctl
#sudo mv ./clusterctl /usr/local/bin/clusterctl # Enable this and remove next one
./clusterctl version -o json
popd

# Change the cluster into a management cluster
/tmp/clusterctl init --infrastructure openstack
```

## Deploy workload

Before deploying workloads, the controllers need to interact with Openstack cloud, one example is ```citycloud```. 

One uses ```openstackrc``` files to interact with Openstack from command line. Similarly, the controllers require some environment variables with relevant values.

These environment variables are divided into two groups. One group is generated using a script while the second group needs to be filled manually.


**Script generated environment variables**

Create a ```clouds.yaml``` file with relevant fields and values shown below.

```yaml
clouds:
  mycloud_dev2:
    auth:
      auth_url: https://test1.mycloud.com:5000
      project_name: Default Project 37137
      username: <change me>
      password: <change me>
      version: 3
      domain_name: CCP_Domain_37137
      user_domain_name: "CCP_Domain_37137"
      project_name: "dev2"
      tenant_name: "dev2"
    region_name: Kna1
    cacert: /path/to/cacert.pem
  mycloud_default:
    auth:
      auth_url: https://test1.mycloud.com:5000
      project_name: Default Project 37137
      username: <change me>
      password: <change me>
      version: 3
      domain_name: CCP_Domain_37137
      user_domain_name: "CCP_Domain_37137"
      project_name: "Default Project 37137"
      tenant_name: "Default Project 37137"
    region_name: Kna1
    cacert: /path/to/cacert.pem
```

Now, parse ```clouds.yaml``` and generate the environment variables

```bash
wget https://raw.githubusercontent.com/kubernetes-sigs/cluster-api-provider-openstack/master/templates/env.rc \
-O /tmp/env.rc
source /tmp/env.rc clouds.yaml mycloud_default
```

Verify the values

```bash
echo $CAPO_CLOUD
echo $OPENSTACK_CLOUD
echo $OPENSTACK_CLOUD_CACERT_B64 | base64 -d
echo $OPENSTACK_CLOUD_PROVIDER_CONF_B64 | base64 -d
echo $OPENSTACK_CLOUD_YAML_B64 | base64 -d
```

These variables are used for authenticating against openstack cluster ```mycloud_default``` (as shown in clouds.yaml file)

**Manually generated environment variables**

In addition to these, the following variables are relevant for provisioning controlplane and worker nodes. 
They need to be set manually as well.

```bash
export OPENSTACK_SSH_KEY_NAME=<change me>
export OPENSTACK_DNS_NAMESERVERS=8.8.8.8
export OPENSTACK_FAILURE_DOMAIN=nova

export OPENSTACK_EXTERNAL_NETWORK_ID=<change me>
export OPENSTACK_CONTROLPLANE_IP=<change me>
export OPENSTACK_IMAGE_NAME=Ubuntu-18.04-2
export OPENSTACK_CONTROL_PLANE_MACHINE_FLAVOR=2C-4GB-100GB
export OPENSTACK_NODE_MACHINE_FLAVOR=2C-4GB-100GB
export OPENSTACK_SSH_AUTHORIZED_KEY="change-me"
```

# Use cases 

Now that the required environmetal variables are created, we can deploy the workload.

## CAPO with no loadbalancer

Create the workload

```bash
clusterctl config cluster basic-1 --kubernetes-version v1.19.1 > /tmp/basic-1.yaml 
```

This gives a single file with multiple objects. It requires some changes as described below. Creating the resources in the given order could help in understanding the relationship between the objects.

**Secret**

```yaml
apiVersion: v1
data:
  cacert: <content of cacert.pem in base64 format>
  clouds.yaml: <see decode string below>
kind: Secret
metadata:
  labels:
    clusterctl.cluster.x-k8s.io/move: "true"
  name: basic-1-cloud-config
  namespace: default

```

clouds.yaml
```yaml
clouds:
  mycloud_default:
    auth:
      auth_url: https://test1.mycloud.com:5000
      project_name: Default Project 37137
      username: <username here>
      password: <password here>
      version: 3
      domain_name: CCP_Domain_37137
      user_domain_name: "CCP_Domain_37137"
      project_name: "Default Project 37137"
      tenant_name: "Default Project 37137"
    region_name: Kna1
    cacert: /tmp/cacert.pem
```

**Openstackcluster**

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackCluster
metadata:
  name: basic-1
  namespace: default
spec:
  cloudName: mycloud_default
  cloudsSecret:
    name: basic-1-cloud-config
    namespace: default
  disablePortSecurity: false 
  dnsNameservers:
  - 8.8.8.8
  managedAPIServerLoadBalancer: false 
  managedSecurityGroups: true
  externalNetworkId: 375af7fe-a2c1-4c26-a57d-6d33175a6650
  nodeCidr: 10.6.0.0/24
  useOctavia: false
  controlPlaneAvailabilityZones:
  - nova
```
Make sure that the following values are set correctly. 

```bash
  disablePortSecurity: false 
  managedAPIServerLoadBalancer: false 
```
Also, the ```externalNetworkId``` value may change from time to time. Therefore, you need to update the environment variable ```OPENSTACK_EXTERNAL_NETWORK_ID```. The following command could help with that.

```bash
#!/bin/bash
EXTERNAL_NETWORK_ID=$(openstack network show airship-ci-ext-net -f value -c id)
echo ${EXTERNAL_NETWORK_ID}
```

**cluster**
```yaml
apiVersion: cluster.x-k8s.io/v1alpha3
kind: Cluster
metadata:
  name: basic-1
  namespace: default
spec:
  clusterNetwork:
    pods:
      cidrBlocks:
      - 192.168.0.0/16
    serviceDomain: cluster.local
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
    kind: KubeadmControlPlane
    name: basic-1-control-plane
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
    kind: OpenStackCluster
    name: basic-1
```

At this point, the following resources are created in the Openstack cloud.

```bash
# Security groups
k8s-cluster-default-basic-1-secgroup-controlplane
k8s-cluster-default-basic-1-secgroup-worker

# Floating IP
A floating IP is created, but is not attached to any instance. If you do not create the CP node quickly enough, 
the floating IP will be taken away. Since the kubeconfig is already generated with that floating IP, the creation of cluster will not proceed.

# Network, subnet and router all with the same name are created
k8s-clusterapi-cluster-default-basic-1	
```

Now, it is time to provision a controlplane node.

**kcp machine template**

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackMachineTemplate
metadata:
  name: basic-1-control-plane
  namespace: default
spec:
  template:
    spec:
      cloudName: mycloud_default
      cloudsSecret:
        name: basic-1-cloud-config
        namespace: default
      flavor: 2C-4GB-100GB
      image: Ubuntu_20.04_node
      sshKeyName: <Add ssh key here>
```

**kcp resource**

```yaml
apiVersion: controlplane.cluster.x-k8s.io/v1alpha3
kind: KubeadmControlPlane
metadata:
  name: basic-1-control-plane
  namespace: default
spec:
  infrastructureTemplate:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
    kind: OpenStackMachineTemplate
    name: basic-1-control-plane
  kubeadmConfigSpec:
    clusterConfiguration:
      apiServer:
        extraArgs:
          cloud-config: /etc/kubernetes/cloud.conf
          cloud-provider: openstack
        extraVolumes:
        - hostPath: /etc/kubernetes/cloud.conf
          mountPath: /etc/kubernetes/cloud.conf
          name: cloud
          readOnly: true
      controllerManager:
        extraArgs:
          cloud-config: /etc/kubernetes/cloud.conf
          cloud-provider: openstack
        extraVolumes:
        - hostPath: /etc/kubernetes/cloud.conf
          mountPath: /etc/kubernetes/cloud.conf
          name: cloud
          readOnly: true
        - hostPath: /etc/certs/cacert
          mountPath: /etc/certs/cacert
          name: cacerts
          readOnly: true
      imageRepository: k8s.gcr.io
    files:
    - content: <configuration file, shown below>
      encoding: base64
      owner: root
      path: /etc/kubernetes/cloud.conf
      permissions: "0600"
    - content: <content of cacert.pem in base64 format>
      encoding: base64
      owner: root
      path: /etc/certs/cacert
      permissions: "0600"
    initConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-config: /etc/kubernetes/cloud.conf
          cloud-provider: openstack
        name: '{{ local_hostname }}'
    joinConfiguration:
      nodeRegistration:
        kubeletExtraArgs:
          cloud-config: /etc/kubernetes/cloud.conf
          cloud-provider: openstack
        name: '{{ local_hostname }}'
  replicas: 1
  version: v1.19.1

```

configurion (equivalent to the yaml format shown above)

```ini
[Global]
auth-url=https://test1.mycloud.com:5000
username=<username here>
password=<password here>
tenant-name="Default Project 37137"
domain-name="CCP_Domain_37137"
ca-file="/etc/certs/cacert"
region="Kna1"
```

**Note:**
- There is no cloud init data specified in the above kcp resource.
  

Creating the above resources will result in a KCP node with a floating IP. It is now possible to interact with the cluster using kubectl. 

```bash
kubectl get secret basic-1-kubeconfig -o json  | jq -r '.data.value' | base64 -d > /tmp/k.config.yaml
kubectl get nodes --kubeconfig /tmp/k.config.yaml
```
Next, we add a worker node


**Worker machine template**

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackMachineTemplate
metadata:
  name: basic-1-md-0
  namespace: default
spec:
  template:
    spec:
      cloudName: mycloud_default
      cloudsSecret:
        name: basic-1-cloud-config
        namespace: default
      flavor: 2C-4GB-100GB
      image: Ubuntu_20.04_node
      sshKeyName: <Add ssh key here>
```

**kubeadmconfigtempalte**

```yaml
apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
kind: KubeadmConfigTemplate
metadata:
  name: basic-1-md-0
  namespace: default
spec:
  template:
    spec:
      files:
      - content: <same configuraiton in init format>
        encoding: base64
        owner: root
        path: /etc/kubernetes/cloud.conf
        permissions: "0600"
      - content: <content of cacert.pem in base64 format>
        encoding: base64
        owner: root
        path: /etc/certs/cacert
        permissions: "0600"
      joinConfiguration:
        nodeRegistration:
          kubeletExtraArgs:
            cloud-config: /etc/kubernetes/cloud.conf
            cloud-provider: openstack
          name: '{{ local_hostname }}'
```

**MachineDeployment**

```yaml
apiVersion: cluster.x-k8s.io/v1alpha3
kind: MachineDeployment
metadata:
  name: basic-1-md-0
  namespace: default
spec:
  clusterName: basic-1
  replicas: 1
  selector:
    matchLabels: null
  template:
    spec:
      bootstrap:
        configRef:
          apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
          kind: KubeadmConfigTemplate
          name: basic-1-md-0
      clusterName: basic-1
      failureDomain: nova
      infrastructureRef:
        apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
        kind: OpenStackMachineTemplate
        name: basic-1-md-0
      version: v1.19.1
```

The end result is one KCP and one worker nodes.

```bash
est-xenwar@xen-machine ~ % kubectl get nodes --kubeconfig /tmp/k.config.yaml

NAME                          STATUS     ROLES    AGE    VERSION
basic-1-control-plane-h9q7x   NotReady   master   37m    v1.19.3
basic-1-md-0-njdvw            NotReady   <none>   8m8s   v1.19.3
```

# Known issues

During the process of using CAPO, some issues were encountered. 
Some of them are related to the development environment, and some are related to CAPO itself. 

**```yq``` version mismtach**

The ```env.rc``` downloaded earlier makes use of ```yq=3.x.x```. 
However, package managers (such as yum) may install ```yq=4.x.x```. If that is the case, use the following script to replace ```yq```.

  ```bash
  GO111MODULE=on go get github.com/mikefarah/yq/v3
  # replace existing 
  sudo mv $GOPATH/bin/yq $(which yq)
  ```

**Deleting old environment variables**

If you run the script multiple times and wish to remove old environment variable values, copy-paste the output of the following commands to unset the values.

```bash
env | grep OPENSTACK | cut -f1 -d= | awk '{{print "unset "$1}}'
env | grep CAPO | cut -f1 -d= | awk '{{print "unset "$1}}'
```

**Openstack client**

If you do not have the openstack client installed, you can use the following docker container.

```bash
docker run -it openstacktools/openstack-client /bin/bash
```

Once inside the container, source the **openstackrc** file and run relevant ```opensack``` commands

## Node life cycle issues

**Scaling up KCP for the first time**

Scaling up a KCP from 1 to 3 is successful

**Scaling down KCP**

Scaling down a KCP from 3 to 1 is successful

**Scaling up KCP after scaling it down**

Scaling up a KCP from 1 to 3 hangs at 2 KCP nodes. Also, the KCP resource is out of sync from the Openstack Dashboard and the node list. 

KCP
```bash
~ % kubectl get kcp -w
NAME                    INITIALIZED   API SERVER AVAILABLE   VERSION   REPLICAS   READY   UPDATED   UNAVAILABLE
basic-1-control-plane   true                                 v1.19.1   3                  3         3
```

node list
```bash
~ % kubectl get nodes --kubeconfig /tmp/k.config.yaml
NAMESPACE   NAME                          STATUS     ROLES    AGE     VERSION
            basic-1-control-plane-zbccd   NotReady   master   2m57s   v1.19.3
            basic-1-control-plane-zbccd   NotReady   master   3m9s    v1.19.3
```

**Stopping a KCP node**

With 3 KCP nodes, stopping a node that has the floating IP assigned to it will result in the floating IP migrating to the other nodes.

**Deleting a KCP node**

With 3 KCP nodes, deleting a node leaves only two nodes. No new node is provisioned to compensate for the missing one. However, as described above, the KCP manifest shows 3 nodes.

**Travelling floating IP**

When scaling up KCP from 1 to 3 nodes, the process succeeds as discussed earlier. However, the floating IP jumps from node to node for no apparent reason. But, this has no impact when using ```kubectl``` commands.
