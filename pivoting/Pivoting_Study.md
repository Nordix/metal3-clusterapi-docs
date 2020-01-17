# Pivoting Study
Pivoting is the process of moving controllers and objects from one k8s cluster to another. The purpose of this document is to describe the process, the challenges encountered and future works.

The following controllers and objects are relevant in the context of baremetal based kubernetes deployment.

**Controllers:** CAPI, CAPBK, CAPBM and BMO
**Main Objects:** Cluster, Machine, MachineSet, MachineDeployment, 
BareMetalCluster, BareMetalMachine and BareMetalHost
**Related Objects:** Cluster Secrets, BareMetalHost Secrets, Configmaps

 The following table lists the controllers with their versions used in this process.

| Repo        | Version           | Branch  |
| ------------- |:-------------:| -----:|
| kubernetes      | 1.17.0 | master |
| CAPI      | v1alpha2      |   release-0.2 |
| CAPBM |    v1alpha2      |   master |
| BMO |    v1alpha1      |   master |

The clusterctl that we have developed specifically for pivoting BareMetal based deployments is based on CAPI-clusterctl release-0.2

### Pivoting process

- The source of truth as of ```release-0.2``` is the provider components yaml file. 
- ```clusterctl``` binary takes the source and target clusters' kubeconfig and the provider components file as arguments.
- Using the provider components file the CRDs, CRs and controllers are created on the target cluster. Once the creation is done, the controllers are scaled down in the source cluster.
- The CAPI objects and the BM deployment specific objects are created/moved in the target cluster and deleted in the source cluster. But the BMHs are not deleted from the source cluster.

### Challenges Encountered 
As of clusterctl release-02, pivoting lacks the following features which are critical in baremetal based deployments.

1. Pivoting objects other than CAPI
   As described in the 'Pivoting process', CRDs, CRs and controllers are created on the target cluster. Related core objects, such as secrets, are also moved. However, provider specific objects such as bmh and objecs related with them are not moved. 

   We have enhanced the clusterctl code to handle moving of bmh and related objects.

2. Moving BMH with status
   Since we have a unique requirement of pivoting BMH object with status preserved from source cluster, we added this feature to patch the BMH object in the target cluster to preserve status from the source cluster. 

3. Maintaining connectivity towards provisioning network
   Baremetal machines boot over a network with a dhcp server. This requires maintaing a fixed IP end points towards the provisioning network. We achieved this using keepalived. 

4. Maintaining dhcp leases 
   During the pivoting process, the pool of baremetal physical machines remains the same. As to avoid IP address assignment conflicts,  maintaining the same dhcp leases in the target cluster is required.
   To this end, we have added a configmap with the content of dhcp leases from the source cluster. The configmap is mounted as a volume in the dnsmasq container of the BMO controller in the target cluster. This ensured that the dnsmasq container is booted with the right leases content.

### Future works
While working with the current version ```clusterctl```, we have observed the following inconsistencies and propose the following enhancements.

1. Linking objects
   Currently, objects are linked using labels, annotations, OwnerRefernces and ConsumerReferences. We need to choose one method that makes the pivoting code generic enough.
2. PivotedReady flag for moved objects
   Once an object is moved to a target cluster, there needs to be a uniform flag that indicates it has been successfully created and any subsequent objects can be created. 
3. RollBack failed pivoting process
   Currently, if pivoting fails, both the target and source clusters are left in an undesired state. The pivoting process needs to be atomic, i.e. all or none.

## Pivoting Steps
Please run the following commands to perform pivoting.
replace the target TARGET_CLUSTER with the IP of the target cluster

### Pre-pivot
```bash
#!/bin/bash
TARGET_CLUSTER=192.168.111.21
# Source cluster: collect kubeconfig for source and target clusters.
cd ~/metal3-dev-env/
cp ~/.kube/config source.yaml
scp ubuntu@"${TARGET_CLUSTER}":/home/ubuntu/.kube/config target.yaml
# Source cluster: create a text file from lease files
export bmo_pod=$(kubectl  get pods -n metal3 -o name | grep 'metal3-baremetal-operator' | cut -f2 -d'/')
kubectl exec -n metal3 $bmo_pod -c ironic-dnsmasq cat /var/lib/dnsmasq/dnsmasq.leases > /tmp/dnsmasq.leases
# Target cluster: Create config from a lease file content | commands run on the source cluster remotely.
scp /tmp/dnsmasq.leases ubuntu@"${TARGET_CLUSTER}":/tmp/dnsmasq.leases
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl create ns metal3
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl create configmap dnsmasq-leases-configmap --from-file=dnsmasq.leases=/tmp/dnsmasq.leases -n metal3
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl get configmap dnsmasq-leases-configmap -o yaml -n metal3
```
### Pivot

```bash
# Source cluster: Start pivoting
cd ~/go/src/sigs.k8s.io/cluster-api/cmd/clusterctl/
alias pivot='./clusterctl alpha phases pivot -p ~/go/src/sigs.k8s.io/cluster-api/provider-components-target.yaml  -s ~/metal3-dev-env/source.yaml -t ~/metal3-dev-env/target.yaml -v 5'
pivot
```

### Post-Pivot
```bash
# Target Cluster: verify that:
# 1. All controllers are up running (2) bmh state is maintained (3) dhcp leases are loaded correctly.
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl get pods -n metal3
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl get bmh -n metal3 -o yaml
ssh ubuntu@"${TARGET_CLUSTER}" -- export bmo_pod=$(kubectl  get pods -n metal3 -o name | grep 'metal3-baremetal-operator' | cut -f2 -d'/')
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl exec -n metal3 $bmo_pod -c ironic-dnsmasq cat /var/lib/dnsmasq/dnsmasq.leases
# Delete the ironic-endpoint IP from minikube
minikube ssh sudo ip addr del 172.22.0.2/24 dev eth2
#Target cluster: Provision a worker | replace with the correct worker yaml file.
cd ~/metal3-dev-env/
scp worker_New.yaml  ubuntu@"${TARGET_CLUSTER}":/tmp
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl apply -f /tmp/worker_New.yaml -n metal3
# Target cluster: Verify that worker is provisioned.
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl get bmh -n metal3

```

**Note:** The script.sh file contains all of these commands. We should run it using the command ```source ./script.sh``` . Some of the steps might need a waiting period for the pods being up and running in the target cluster.

### To do list

1. Given network address as input, identify which interface to use for provisioning
2. Automate the provider component yaml generation for target
    a. Use relevant interface
    b. Add dhcp-leases specific configmap entries in provider component
3. Change the pivoting code to apply the configmap before applying the provider-component
4. Address multi-cluster and multi-namespace issues for pivoting
5. Standardize identifier of pods (could be done via naming, labels, annotations...)
6. Check the user secret (cloud init) is moved/maintained in the target cluster
7. Change provider id in bmh to be namespace/name
