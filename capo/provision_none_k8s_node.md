# Investigation for deploying non K8S VMs

In order to create a VM that is not part of kubernetes cluster using the CAPO controllers, the following resources are created.

Create Cloud init data, `clouddata.yaml`:

```yaml
## template: jinja
#cloud-config

runcmd:
  - echo "Successfully provisioned a none-k8s node" > /tmp/provisioned.node.txt
users:
  - name: <add username here>
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-rsa AAAAB3 machine.local (Add your key here)
```

Encode the above file in base64:

```bash
cat clouddata.yaml | base64
```

Next, create a `Secret` resource:

```yaml
apiVersion: v1
kind: Secret
type: cluster.x-k8s.io/secret
metadata:
  labels:
    cluster.x-k8s.io/cluster-name: basic-1
  name: clouddata-secret-1
  namespace: default
data:
  value: <Encoded cloud init data>
```

Then we create the `Machine` and `OpenstackMachine` resources.
Note that the `KubeadmConfig` referenced in the `Machine` resource already exists.
It was created earlier when the cluster was provisioned.

`Machine`:

```yaml
apiVersion: cluster.x-k8s.io/v1alpha3
kind: Machine
metadata:
  name: machine-director
  namespace: default
spec:
  bootstrap:
    configRef:
      apiVersion: bootstrap.cluster.x-k8s.io/v1alpha3
      kind: KubeadmConfig
      name: basic-1-md-0-k2kb7
      namespace: default
    dataSecretName: clouddata-secret-1
  clusterName: basic-1
  failureDomain: nova
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
    kind: OpenStackMachine
    name: osm-director
    namespace: default
  version: v1.19.1
```

`OpenstackMachine`:

```yaml
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha3
kind: OpenStackMachine
metadata:
  name: osm-director
  namespace: default
spec:
  cloudName: mycloud_default
  cloudsSecret:
    name: basic-1-cloud-config
    namespace: default
  flavor: 2C-4GB-100GB
  image: Ubuntu_20.04_node
  sshKeyName: <Add ssh key here>
```

## Result

As discussed above, it is possible to create a VM by using CAPO utilities.
The created machine has the following properties:

- It does not join the k8s cluster
- It does not contain sensitive files such as cacert and clouds.yaml
- It is deleted upon the deletion of the cluster.
- It can also be deleted independently of the cluster by deleting the Machine and OpenstackMachine resources
- It can be ssh into using the provided key
- It requires a manual addition of security group in order to enable sshing
- It requires a manual attachment of floating IP in order to perform ssh connectivity
