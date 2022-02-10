## Deploy a mgmt and a workload cluster with clusterctl in kind

### This README is based on docs:
* https://cluster-api.sigs.k8s.io/clusterctl/overview.html
* https://github.com/Nordix/metal3-clusterapi-docs/blob/clusterctl-kashif/clusterCtl-study/testcmd/instrusctions.md
  * note files and details of high importance e.g **clusterctl-settings.json**

### create clusterctl-settings.json

* in **cluster-api** repo

```sh
{
  "providers": [ "cluster-api", "bootstrap-kubeadm", "control-plane-kubeadm",  "infrastructure-metal3"],
  "provider_repos": ["$HOME/work/go/src/sigs.k8s.io/cluster-api-provider-metal3"]
}
```

* in **cluster-api-provider-metal3** repo

```sh
{
  "name": "infrastructure-metal3",
  "config": {
    "componentsFile": "infrastructure-components.yaml",
    "nextVersion": "v0.3.0"
  }
}
```

### create a cluster on localhost

```sh
~$ kind create cluster
```

### get kubeconfig of new kind cluster

```sh
~/.cluster-api$ kind get kubeconfig > kubeconfig
```

### clusterctl local overrides generated from local repositories for the
### cluster-api, bootstrap-kubeadm, control-plane-kubeadm, infrastructure-metal3 providers
### in order to use them, please run:

```sh
~/work/go/src/sigs.k8s.io/cluster-api$ 
cmd/clusterctl/hack/local-overrides.py
```

### copy files for cluster-template.yaml and metadata.yaml

```sh
cp ~/work/go/src/sigs.k8s.io/cluster-api-provider-metal3/examples/clusterctl-templates/clusterctl-cluster.yaml ~/.cluster-api/overrides/infrastructure-metal3/v0.3.0/cluster-template.yaml

cp ~/work/go/src/sigs.k8s.io/cluster-api-provider-metal3/metadata.yaml ~/.cluster-api/overrides/infrastructure-metal3/v0.3.0/metadata.yaml

~/.cluster-api$ tree
.
├── clusterctl.yaml
├── kubeconfig
└── overrides
    ├── bootstrap-kubeadm
    │   └── v0.3.0
    │       └── bootstrap-components.yaml
    ├── cluster-api
    │   └── v0.3.0
    │       └── core-components.yaml
    ├── control-plane-kubeadm
    │   └── v0.3.0
    │       └── control-plane-components.yaml
    ├── infrastructure-baremetal
    │   └── v0.3.0
    │       ├── cluster-template.yaml
    │       ├── infrastructure-components.yaml
    │       └── metadata.yaml
    └── infrastructure-metal3
        └── v0.3.0
            ├── cluster-template.yaml
            ├── infrastructure-components.yaml
            └── metadata.yaml
```

### build clusterctl binary if needed

```sh
~/work/go/src/sigs.k8s.io/cluster-api$
make clusterctl
```

### setup mgmt cluster

```sh
~/work/go/src/sigs.k8s.io/cluster-api/bin$
./clusterctl init --core cluster-api:v0.3.0 --bootstrap kubeadm:v0.3.0 --control-plane kubeadm:v0.3.0 --infrastructure metal3:v0.3.0
```

### add provider to existing mgmt cluster, optional

```sh
~/work/go/src/sigs.k8s.io/cluster-api/bin$
./clusterctl init --infrastructure <e.g aws, metal3, ...>
```

### set env variables
### template (~/work/go/src/sigs.k8s.io/cluster-api-provider-metal3/examples/clusterctl-templates/example_variables.rc)
### Note: CIDR etc can be found from 'kubectl describe clusters'

```sh
~/work/go/src/sigs.k8s.io/cluster-api/bin$
source ~/work/go/src/sigs.k8s.io/cluster-api-provider-metal3/examples/clusterctl-templates/<test_variables.rc>
```

### setup workload clusters

```sh
~/work/go/src/sigs.k8s.io/cluster-api/bin$
./clusterctl config cluster test-cluster --kubernetes-version v1.17.0 > cluster-workload.yaml

~/work/go/src/sigs.k8s.io/cluster-api/bin$
kubectl apply -f cluster-workload.yaml
```

### using specific provider

```sh
~/work/go/src/sigs.k8s.io/cluster-api/bin$
./clusterctl config cluster test-xx-cluster --kubernetes-version v1.17.0  --infrastructure <e.g aws, metal3, ...> > cluster-xx-workload.yaml
```

### helpful commands

```sh
kubectl get clusters -A
kubectl get all -A
kubectl get kcp -A
kubectl get clusters -A
kubectl get machinedeployment -A
kubectl api-resources
kubectl get apiservices -A
kubectl get kubeadmconfigs -A
kubectl get m3m -A
kubectl get m3c -A
kubectl get ma -A
kubectl get ms -A
```
