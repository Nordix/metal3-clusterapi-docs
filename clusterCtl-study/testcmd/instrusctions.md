# ClusterCtl V2 Study

## Tasks To do:
Investigate ClusterCtl V2 to know if it is possible to

* invoke clusterctl by giving client object and kubeconfig path as parameters.
For this, clusterctl should be used as a library
* give a custom directory path to store the provider components directory
structure instead of default $HOME/.cluster-api. All the paths in configurations
 should be relative to the custom directory.
* substitute environment variables in provider components
* specify target namespace to support multi-tenancy i.e. multiple clusters in
different namespaces
* support update of provider components
* deploy without using CAKCP/machine deployment. Any templates should be avoided

## Updates So far
* ClusterCtl deployed as a library
* Client object and kubeconfig can be given as a parameters
* Custom-directory for provider components not yet working. Investigation
ongoing.

**Update:** This is not yet supported. It will be supported though as reported in this [CAPI ISSUE](https://github.com/kubernetes-sigs/cluster-api/issues/2404).


Currently it searches provider components in $HOME/.cluster-api
directory. Here is the directory structure:

```
.cluster-api/
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
    ├── docker
    │   └── v0.3.0
    │       └── infrastructure-components.yaml
    ├── infrastructure-metal3
    │   └── v0.3.0
    │       └── infrastructure-components.yaml
    ├── kubeadm-bootstrap
    │   └── v0.3.0
    │       └── bootstrap-components.yaml
    └── kubeadm-control-plane
        └── v0.3.0
            └── control-plane-components.yaml
```
This directory can be used as it is and there is no need to generate it time and
again unless there is an update. This directory is generated when the following
command is executed in cluster-api directory:

` cmd/clusterctl/hack/local-overrides.py`

For this command to succeed the following files should be present in respective
directories:

```
cluster-api$ cat clusterctl-settings.json
{
  "providers": [ "cluster-api", "bootstrap-kubeadm", "control-plane-kubeadm",  "infrastructure-metal3"],
  "provider_repos": ["/home/airshipci/go/src/github.com/metal3-io/cluster-api-provider-metal3"]
}
```

```
cluster-api-provider-metal3$ cat clusterctl-settings.json
{
  "name": "infrastructure-metal3",
  "config": {
    "componentsFile": "infrastructure-components.yaml",
    "nextVersion": "v0.3.0"
  }
}
```
Once these files are in place, the above command will generate the overrides and
the directory structure with provider components in config directory. As
mentioned earlier it can be used as it is , but we should keep in mind that if
crds are to be generated manually they should have the following labels to be
able tobe used with clusterctl:

```
labels:
- clusterctl.cluster.x-k8s.io: ""
- cluster.x-k8s.io/provider: "<provider-name>"
```

## Commands to run the test
` ./testcmd /home/$USER/testcmd/.cluster-api/clusterctl.yaml /home/$USER/testcmd/.cluster-api/kubeconfig  cluster-api:v0.3.0 kubeadm:v0.3.0 kubeadm:v0.3.0 metal3:v0.3.0 metal3 metal3`

`./testcmd /home/$USER/testcmd/.cluster-api/clusterctl.yaml /home/$USER/testcmd/.cluster-api/kubeconfig  cluster-api:v0.3.0 kubeadm:v0.3.0 kubeadm:v0.3.0 metal3:v0.3.0 metal2 metal2`

You can also run the command without specifying the versions for the providers, for example:

`./testcmd /home/$USER/.cluster-api/clusterctl.yaml /home/kashif/testcmd/.cluster-api/kubeconfig  cluster-api kubeadm kubeadm metal3 ns1 ns1`

The command line arguements correspond to config directory,  kubeconfig path,
core provider, bootstrap provider, controlplane provider, infrastructure
provider, target namespace and watching namespace respectively.

However, for this code to run the $HOME/.clusterapi directory with provider
components should be present.

## Upgrade
Update of already deployed provider in a namespace is possible in two different ways:

The first and recommended way of upgrade is to publish all the changes in a release version and publish it in github repo. The `clusterctl upgrade plan` command will pick up new releases from the repo and allow you to upgrade to newer version.

The instructions are available here [clusterctl upgrade](https://master.cluster-api.sigs.k8s.io/clusterctl/commands/upgrade.html).

** Note: ** The current implementation of the upgrade process does not preserve controllers flags that are not set through the components YAML/at the installation time.

The second way to upgrade the provider is with local override. For this lets consider an example that in a cluster currently CAPBM is deployed with v0.3.1 version. The local overrides were created before deploying CAPBM:v0.3.1 and the $HOME/.clusterapi directory exists with the directory structure as depicted previously. Now you have made some changes in the provider components and you want to upgrade the current deployment of CAPBM only with the newer changes. To do that, you first have to create the following file:

```
cat ~/.cluster-api/clusterctl.yaml
providers:
  - name: metal3
    url: /home/airshipci/.cluster-api/overrides/infrastructure-metal3/v0.3.2/infrastructure-components.yaml
    type: InfrastructureProvider
```
As you can see, `clusterctl.yaml` has a manual override of the `metal3` provider which is now pointing to a newer version of CAPBM locally which is v0.3.2. We should keep the updated/new provider components yaml file in the directory mentioned. So now, the $HOME/.clusterapi directory looks like this:

```
tree ~/.cluster-api/
/home/airshipci/.cluster-api/
├── clusterctl.yaml
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
    └── infrastructure-metal3
        ├── v0.3.1
        │   └── infrastructure-components.yaml
        └── v0.3.2
            └── infrastructure-components.yaml
```
Since now we have placed the updated component yaml file in a different version directory, if we now run `clusterctl upgrade plan` we should see the following output:

```
Management group: t2/cluster-api, latest release available for the v1alpha3 API Version of Cluster API (contract):

NAME                       NAMESPACE   TYPE                     CURRENT VERSION   NEXT VERSION
bootstrap-kubeadm          t2          BootstrapProvider        v0.3.0            Already up to date
control-plane-kubeadm      t2          ControlPlaneProvider     v0.3.0            Already up to date
cluster-api                t2          CoreProvider             v0.3.0            Already up to date
infrastructure-metal3   t2          InfrastructureProvider   v0.3.1            v0.3.2

You can now apply the upgrade by executing the following command:

   upgrade apply --management-group t2/cluster-api --contract v1alpha3

```

Once you run the command `clusterctl upgrade apply --management-group t2/cluster-api --contract v1alpha3` you will now have CAPBM redeployed with updated provider component from v0.3.2.

In case, you want to keep the version name as it is but add the build number only, i.e. you now have v0.3.2-rc.2 then `clusterctl upgrade plan` will not identify this as an upgrade for v0.3.2. However, if in the first case the v0.3.2 was tagged as v0.3.2-rc.1, then the command will identify this as an upgrade.
Here is an example:

```
Management group: t8/cluster-api, latest release available for the v1alpha3 API Version of Cluster API (contract):

NAME                       NAMESPACE   TYPE                     CURRENT VERSION   NEXT VERSION
bootstrap-kubeadm          t8          BootstrapProvider        v0.3.0            Already up to date
control-plane-kubeadm      t8          ControlPlaneProvider     v0.3.0            Already up to date
cluster-api                t8          CoreProvider             v0.3.0            Already up to date
infrastructure-metal3   t8          InfrastructureProvider   v0.3.2            Already up to date

You are already up to date!


Management group: ts9/cluster-api, latest release available for the v1alpha3 API Version of Cluster API (contract):

NAME                       NAMESPACE   TYPE                     CURRENT VERSION   NEXT VERSION
bootstrap-kubeadm          ts9         BootstrapProvider        v0.3.0            Already up to date
control-plane-kubeadm      ts9         ControlPlaneProvider     v0.3.0            Already up to date
cluster-api                ts9         CoreProvider             v0.3.0            Already up to date
infrastructure-metal3   ts9         InfrastructureProvider   v0.3.2-rc.2       v0.3.2-rc.3

```
As you can see, the v0.3.2-rc.3 was not identified as an upgrade for v0.3.2 but it was identified as an upgrade from v0.3.2-rc.2.
## Variable substitution
Clusterctl supports variable substitution in provider components file. Here is an example:

```
cat ~/.cluster-api/overrides/infrastructure-metal3/v0.3.2/infrastructure-components.yaml

...
apiVersion: apps/v1
kind: Deployment
...
  name: capbm-controller-manager
  namespace: capbm-system
spec:
  ...
  template:
        ...
        image: ${ CAPBM_IMAGE } #quay.io/metal3-io/cluster-api-provider-metal3:master
        ...
...
```
If we now export the environment variable `export CAPBM_IMAGE=quay.io/metal3-io/cluster-api-provider-metal3:master` and do `clusterctl init ...` clusterctl will replace the environment variable and then deploy the provider components.

## Example clusterctl.yaml file for all provider
```

cat ~/.cluster-api/clusterctl.yaml
providers:
  - name: metal3
    url: /home/airshipci/.cluster-api/overrides/infrastructure-metal3/v0.3.2-rc.3/infrastructure-components.yaml
    type: InfrastructureProvider
  - name: kubeadm
    url: /foo/bar/infrastructure-components.yaml
    type: BootstrapProvider  
  - name: kubeadm
    url:  /foo/bar/infrastructure-components.yaml
    type: ControlPlaneProvider
  - name: cluster-api
    url: /foo/bar/infrastructure-components.yaml
    type: CoreProvider

```
Note that the local repos marked by the `url` tag should follow the same convention as shown in case of CAPBM.
