# Deploy a mgmt and a workload cluster with clusterctl in kind

## This README is based on docs

* <https://cluster-api.sigs.k8s.io/clusterctl/overview.html>
* <https://github.com/Nordix/metal3-clusterapi-docs/blob/clusterctl-kashif/clusterCtl-study/testcmd/instrusctions.md>
* Note files and details of high importance e.g `clusterctl-settings.json`

## Create clusterctl-settings.json

* in `cluster-api` repo

```json
{
  "providers": [ "cluster-api", "bootstrap-kubeadm", "control-plane-kubeadm",  "infrastructure-metal3"],
  "provider_repos": ["$HOME/work/go/src/sigs.k8s.io/cluster-api-provider-metal3"]
}
```

* in `cluster-api-provider-metal3` repo

```json
{
  "name": "infrastructure-metal3",
  "config": {
    "componentsFile": "infrastructure-components.yaml",
    "nextVersion": "v0.3.0"
  }
}
```

## Create a cluster on localhost

```bash
kind create cluster
```

## Get kubeconfig of new kind cluster

```bash
~/.cluster-api$ kind get kubeconfig > kubeconfig
```

clusterctl local overrides generated from local repositories for the cluster-api, bootstrap-kubeadm, control-plane-kubeadm, infrastructure-metal3 providers. In order to use them, please run:

```bash
cmd/clusterctl/hack/local-overrides.py
```

## copy files for cluster-template.yaml and metadata.yaml

```bash
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

## Build clusterctl binary if needed

```bash
make clusterctl
```

## Setup mgmt cluster

```bash
./clusterctl init --core cluster-api:v0.3.0 --bootstrap kubeadm:v0.3.0 --control-plane kubeadm:v0.3.0 --infrastructure metal3:v0.3.0
```

## Add provider to existing mgmt cluster, optional

```bash
./clusterctl init --infrastructure <e.g aws, metal3, ...>
```

## Set environment variables

Template (`cluster-api-provider-metal3/examples/clusterctl-templates/example_variables.rc`)
**Note**: CIDR etc can be found from `kubectl describe clusters`

```bash
source ~/work/go/src/sigs.k8s.io/cluster-api-provider-metal3/examples/clusterctl-templates/<test_variables.rc>
```

## Setup workload clusters

```bash
./clusterctl config cluster test-cluster --kubernetes-version v1.17.0 > cluster-workload.yaml
kubectl apply -f cluster-workload.yaml
```

## Using specific provider

```bash
./clusterctl config cluster test-xx-cluster --kubernetes-version v1.17.0  --infrastructure <e.g aws, metal3, ...> > cluster-xx-workload.yaml
```

## Helpful commands

```bash
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
