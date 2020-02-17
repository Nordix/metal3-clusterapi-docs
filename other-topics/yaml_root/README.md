
The following directory tree shows the organization of manually collected yaml files. 

The ```infra_crs``` folder contains examples crs the respective controllers and resources.
The ```managers``` folder contains deployments and related resources for the respective controllers. 
The ```provider-components``` folder contains CRDs for the respective resources.

```
yaml_root
├── infra_crs
│   ├── bmo
│   │   └── cr_baremetalhost.yaml
│   ├── cabpk
│   │   ├── Kubeadmconfigtemplate.yaml
│   │   └── kubeadmconfig.yaml
│   ├── capbm
│   │   ├── baremetalcluster.yaml
│   │   ├── bareMetalmachinetemplate.yaml
│   │   └── baremetalmachine.yaml
│   └── capi
│       ├── cluster.yaml
│       ├── cr_cert-manager.yaml
│       ├── machinedeployment.yaml
│       └── machine.yaml
├── managers
│   ├── bmo
│   │   └── manager-baremetal_operator.yaml
│   ├── cabpk
│   │   └── manager-kubeadm.yaml
│   ├── capbm
│   │   └── manager-capbm.yaml
│   └── capi
│       └── manager-cluster-api.yaml
└── provider-components
    ├── bmo
    │   ├── crd_baremetalhost.yaml
    │   └── metal3.io_baremetalhosts_crd.yaml
    ├── cabpk
    │   └── provider-components-kubeadm.yaml
    ├── capbm
    │   └── provider-components-capbm.yaml
    └── capi
        ├── crd_cert-manager.yaml
        └── provider-components-cluster-api.yaml

```
