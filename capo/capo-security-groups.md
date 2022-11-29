# Investigations regarding security groups

In this document, we try to address the following points. The shorter versions of the answers are given here and details will follow.

1. Can we give already existing security groups ?
  **Yes, pre-created security groups can be used**
2. Can it create the security groups, given a set of rules ?
  **No, there is no way of creating security groups using CAPO manifests**
3. Can we create specific security groups per network per machine deployment / KCP ?
  **No, there is no way of creating security groups using CAPO manifests**

## Use existing security groups

Existing security groups can be used by referencing their names in the `OpenStackMachineTemplate` resource.

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackMachineTemplate
metadata:
  name: basic-1-control-plane
  namespace: default
spec:
  template:
    spec:
      securityGroups:
      - name: capo-precreated-sg # This is pre-created already
      cloudName: mycloud_default
      cloudsSecret:
        name: basic-1-cloud-config
        namespace: default
      flavor: 2C-4GB-100GB
      image: Ubuntu_20.04_node
      sshKeyName: xenwar-key
```

## View security groups

The security groups and their respective groups are shown in the `OpenstackCluster` resource.

```json
kubectl get openstackcluster basic-1 -o json | jq '.status|.controlPlaneSecurityGroup,.workerSecurityGroup'

{
  "id": "1c5191d5-754c-4e0d-9ac0-5e7fc39519f3",
  "name": "k8s-cluster-default-basic-1-secgroup-controlplane",
  "rules": [
    {
      "description": "Kubernetes API",
      "direction": "ingress",
      "etherType": "IPv4",
      "name": "4c6c9283-ce93-46fb-983c-8fd2544a0e7a",
      "portRangeMax": 6443,
      "portRangeMin": 6443,
      "protocol": "tcp",
      "remoteGroupID": "",
      "remoteIPPrefix": "0.0.0.0/0",
      "securityGroupID": "1c5191d5-754c-4e0d-9ac0-5e7fc39519f3"
    },
    {
      "description": "Kubelet API",
      "direction": "ingress",
      "etherType": "IPv4",
      "name": "856812e1-4bd1-4bb8-9982-04a8575a28d0",
      "portRangeMax": 10250,
      "portRangeMin": 10250,
      "protocol": "tcp",
      "remoteGroupID": "1c5191d5-754c-4e0d-9ac0-5e7fc39519f3",
      "remoteIPPrefix": "",
      "securityGroupID": "1c5191d5-754c-4e0d-9ac0-5e7fc39519f3"
    },
    {
      "description": "Etcd",
      "direction": "ingress",
      "etherType": "IPv4",
      "name": "c37e1f11-d9d6-4dfa-8ae2-036e6e152472",
      "portRangeMax": 2380,
      "portRangeMin": 2379,
      "protocol": "tcp",
      "remoteGroupID": "1c5191d5-754c-4e0d-9ac0-5e7fc39519f3",
      "remoteIPPrefix": "",
      "securityGroupID": "1c5191d5-754c-4e0d-9ac0-5e7fc39519f3"
    },
  ]
}
{
  "id": "90a83b73-1e65-4992-bf0d-c2aef4758fdd",
  "name": "k8s-cluster-default-basic-1-secgroup-worker",
  "rules": [
    {
      "description": "Kubelet API",
      "direction": "ingress",
      "etherType": "IPv4",
      "name": "48180e24-fd9a-45de-82e8-6e9a0a47a5fc",
      "portRangeMax": 10250,
      "portRangeMin": 10250,
      "protocol": "tcp",
      "remoteGroupID": "1c5191d5-754c-4e0d-9ac0-5e7fc39519f3",
      "remoteIPPrefix": "",
      "securityGroupID": "90a83b73-1e65-4992-bf0d-c2aef4758fdd"
    },
    {
      "description": "Node Port Services",
      "direction": "ingress",
      "etherType": "IPv4",
      "name": "b41fe119-f56d-40f0-a141-8ee3e707e0ac",
      "portRangeMax": 32767,
      "portRangeMin": 30000,
      "protocol": "tcp",
      "remoteGroupID": "",
      "remoteIPPrefix": "0.0.0.0/0",
      "securityGroupID": "90a83b73-1e65-4992-bf0d-c2aef4758fdd"
    },
  ]
}
```

For pre-created security groups referenced in `OpenStackMachineTemplate.spec.template.spec.securityGroups.name`, the details need to be retrieved from openstack itself.

## Create new security groups

As of now, there is no way of creating a security group using CAPO manifests. The security groups and their respective rules in use for the controlplane and worker servers are hard coded as shown in [controlPlaneRules](https://github.com/kubernetes-sigs/cluster-api-provider-openstack/blob/8d40447beb68e9b199973ba42023a0ecdddc6f5c/pkg/cloud/services/networking/securitygroups.go#L149) and [workerRules](https://github.com/kubernetes-sigs/cluster-api-provider-openstack/blob/8d40447beb68e9b199973ba42023a0ecdddc6f5c/pkg/cloud/services/networking/securitygroups.go#L225)
