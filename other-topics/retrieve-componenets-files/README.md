The purpose of the scripts contained in `scripts` folder is to retrieve crds and related yaml files from multiple repos and put them in one location. The following three repos used and other can be added as well. All repos are pulled from github.

```
https://github.com/metal3-io/cluster-api-provider-baremetal.git
https://github.com/metal3-io/baremetal-operator.git
https://github.com/kubernetes-sigs/cluster-api.git
```

`get_bases_files`: copies the files with their respective folder structure but replaces all instances of variables with a string. 

Example:
```bash
# change the branches based on your needs| default is master branch for all
export BMO_RELEASE="master"
export CAPI_RELEASE="release-0.2"
export CAPBM_RELEASE="release-0.2"

./get_bases_files [output folder] # default is current directory
```

output folder structure
```
tree -L 4
.
├── _bases
│   ├── bmo
│   │   └── deploy
│   │       ├── crds
│   │       ├── default
│   │       ├── ironic_ci.env
│   │       ├── ironic-keepalived-config
│   │       ├── kustomization.yaml
│   │       ├── namespace
│   │       ├── operator
│   │       └── rbac
│   ├── capbk
│   │   └── config
│   │       ├── certmanager
│   │       ├── crd
│   │       ├── default
│   │       ├── kustomization.yaml
│   │       ├── manager
│   │       ├── rbac
│   │       └── webhook
│   ├── capbm
│   │   └── config
│   │       ├── certmanager
│   │       ├── crd
│   │       ├── default
│   │       ├── kustomization.yaml
│   │       ├── manager
│   │       ├── rbac
│   │       └── webhook
│   ├── capi
│   │   └── config
│   │       ├── certmanager
│   │       ├── ci
│   │       ├── core
│   │       ├── crd
│   │       ├── default
│   │       ├── kustomization.yaml
│   │       ├── manager
│   │       ├── rbac
│   │       └── webhook
│   └── kustomization.yaml

```