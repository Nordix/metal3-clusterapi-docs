# Investigations regarding networking

This document discusses ways of managing networks using the CAPO controller. As a summary, we have tried to answer some of the following questions. A shorter version of the answers is given in line and more details are added in the relevant section.

Q: Is it possible to make use of existing networks ?
**A: Yes, servers can be connected to existing networks**

Q: Is it possible for CAPO to create all needed networks ?
**No, only the internal network is created by CAPO, other networks should be created by users**

Q: Should all networks be specififed in the KCP/worker manifests ?
**Yes, all networks, including the internal networks created by CAPO should be provided**

Q: Can all networks be omitted
**Yes, if no network is given in the manifests, then the internal network will be added implicitly.**

Q: In addition to the internal network, can a server be connected more networks ?
Q: Can the other neworks be specified differently per KCP ?
Q: Can the other neworks be specified differently per worker ?

for the above questions, there are three cases.

**case 1:** All nodes taking the same additional networks
        This is possible by adding the networks in OpenStackMachineTemplate/OpenStackMachine for the KCP/worker manifests.
**case 2:** All KCP and workers taking traffic-net-1 and traffic-net-2 respectively.
        This is also possible as the OpenStackMachineTemplate/OpenStackMachine are seprate for KCP and worker nodes.
**case 3:** Each KCP node taking an addition network of its own and Each worker taking an additional network of its own
        This is not possible as the OpenStackMachineTemplate/OpenStackMachineTemplate are immutable resources. This would require deleting and re-creating them. Since KCP and machine deployments are dependent on them, it is not possible without deleting the actual servers.

## supported fields

### network

Resource: OpenStackMachineTemplate/OpenStackMachine

To specify multiple networks, the ```OpenStackMachineTemplate``` resource needs to be created after the ```Cluster``` resource is created. When the ```Cluster``` is created, the internal network is created by CAPO.

In order to connect a node with multiple external networks, 
1. Create the cluster so that the internal network is created. 
2. Create additional networks.
3. Gather network and subnet uuid for each of the external networks and the internal networks and put the values in the ```OpenStackMachineTemplate/OpenStackMachine``` resources.

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackMachineTemplate
metadata:
  name: basic-1-md-0
  namespace: default
spec:
  template:
    spec:
      ...
      sshKeyName: xenwar-key
      trunk: false
      networks:
        # Internal network created by CAPO
      - uuid: 50734e49-3777-4dfe-962a-da0f6106e009
        subnets:
        - filter:
            id: 58f297c2-ca0f-4c21-9efa-bb69f7138d3f
      # external network 1
      - uuid: 321ff535-7d59-4872-a437-48f1e9d33457
        subnets: # required
        - filter:
            id: 2f796e80-65e4-4589-b92d-77a6c019fe35
      # external network 2
      - uuid: 5e8a3bca-0e52-426e-9022-fd17c24476ea
        subnets:
        - filter:
            id: 8579b198-e9ac-4f8b-a5e8-ed905dacc1b6
      # external network 3
      - uuid: 06e509cd-abf2-42b9-a45b-8c9b5c4aa483
        subnets:
        - filter:
            id: 5d4d5e3e-8c14-473b-a1ec-2d67394ad1b6
```

Note that when adding multiple networks, there is a routing issue and adding a floating IP on any of the interfaces would not allow sshing into the VM. A quick solution is to remove and re-add the interfaces.

Also, specifying different network for a portion of KCP or machineDeployments is not possible. i.e. All KCP nodes are generated from the same ```openstackMachineTemplate```. The same applies to the machineDeployments. Trying to modify the networks of an existing openstackMachineTemplate results in the following error.

```yaml
Error from server (openstackMachineTemplateSpec is immutable): 
error when replacing "vms/osmachinetemplate_worker.yaml": 
admission webhook "validation.openstackmachinetemplate.infrastructure.x-k8s.io" denied the request: 
openstackMachineTemplate is immutable
```

### fixedIp:

Resources: OpenStackMachineTemplate/OpenStackMachineTemplate
Result: Fixed address values are selected by CAPO and field value is not enforced.

Two methods of adding fixedIPs was tried
1. Directly adding IPv4 adddress has no effect
2. Creating a port with static IP and giving the port name has no effect

i.e. CAPO selects the fixed IP and there is no way of overriding that.

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackMachineTemplate
metadata:
  name: basic-1-md-0
  namespace: default
spec:
  template:
    spec:
      sshKeyName: xenwar-key
      - uuid: 321ff535-7d59-4872-a437-48f1e9d33457
        fixedIp: 10.11.0.51 # or PORT name
        subnets:
        - filter:
            id: 2f796e80-65e4-4589-b92d-77a6c019fe35
```

### port_security_enabled per port

Resource: OpenStackCluster
Result: Not supported

Enabling or disabling port security per port is not possible as the value is set at the network level of the cluster.
Also notice that the value is set for the entire network at the cluster level. 
There is no way of setting via ```openstackmachine.spec.networks```.

```yaml
kubectl explain openstackcluster.spec.disablePortSecurity
KIND:     OpenStackCluster
VERSION:  infrastructure.cluster.x-k8s.io/v1alpha3

FIELD:    disablePortSecurity <boolean>

DESCRIPTION:
     DisablePortSecurity disables the port security of the network created for
     the Kubernetes cluster, which also disables SecurityGroups
```

### binding:vnic_type: 
No information available, Not supported
### value_specs: 
No information available, Not supported
### allowed_address_pairs: 
No information available, Not supported
### vinc_type: 
No information available, Not supported
 
### trunk_port

Resources: OpenStackMachine, OpenStackMachineTemplate

Result: CAPO supports it, but the Openstack cloud we are using does not. 

```bash
E0223 14:27:04.644406       1 openstackmachine_controller.go:460] 
controllers/OpenStackMachine "msg"="OpenStack instance cannot be created: error creating Openstack instance: there is no trunk support. Please disable it" 
"error"="UpdateError" 
"cluster"="basic-1" 
"machine"="basic-1-md-0-7dd455f64f-9v7rk" 
"namespace"="default" 
"openStackCluster"="basic-1" 
"openStackMachine"="basic-1-md-0-9kgj8"
```

### security_groups

Already discussed in the [security group study document](capo-security-groups.md).
