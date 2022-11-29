# Introduction

The purpose of this document is to give easy step-by-step instructions how to set up Kind cluster and use Tilt for Cluster API development and testing. For the reminder of this document, we use Kind as management cluster and Cluster API Provider Docker (CAPD) as infrastructure provider.

## Prerequisites

1. Go version 1.13.0+
2. Docker
3. Kind v0.6 or v0.7 (other clusters can be used if preload_images_for_kind is set to false)
4. Kustomize standalone (kubectl kustomize does not work because it is missing some features of kustomize v3)
5. Tilt v0.10.3 or newer
6. Clone the Cluster API repository locally. CAPD and Cluster API Bootstrap Provider Kubeadm (CABPK) comes with Cluster API.

## Cloning Git Repo

```bash
git clone https://github.com/kubernetes-sigs/cluster-api.git
```

## Install Kind

Kind is a tool for running local Kubernetes clusters using Docker container "nodes". Run following commands to install Kind:

```bash
GO111MODULE="on" go get sigs.k8s.io/kind@v0.7.0
```

**Note:** In Kind v0.8.0 the default docker network for nodes is different from older versions. This has cause problems, so always use version v0.7.0.

## Install tilt

Tilt is a handy tool for local kubernetes development. The good thing about tilt is that it watches files for edits and automatically builds the container images, and applies any changes to bring the environment up-to-date in real-time. [Tilt](https://docs.tilt.dev/install.html) can be installed using the following command:

```bash
curl -fsSL https://raw.githubusercontent.com/windmilleng/tilt/master/scripts/install.sh | bash
```

You should verify if the installation is correct:

```bash
tilt version
```

**Note:**

1. Tilt requires **Docker** to be installed as a non-root user and **kubectl** binary. It is assumed that this is already taken care of in your local environment.
2. Tilt also requires a working kubernetes cluster to work on. For this purpose we are using **Kind**.

## Kind cluster

Because the Docker provider needs to access Docker on the host, a custom kind cluster configuration is required. Create new `Kind` cluster with `kind-cluster-with-extramounts.yaml`:

```bash
kind create cluster --config ./kind-cluster-with-extramounts.yaml
```

## Tiltfile

The cluster api repository has a `Tiltfile` in the root directory. This `Tiltfile` contains all needed to tilt up the environment.

## Create tilt-settings.json

Create a tilt-settings.json file and place it in your local copy of cluster-api. When using Kind, you’ll need a way to push your images to a registry to they can be pulled. Most users test with GCR, but you could also use something like Docker Hub. Here is an example:

```json
{
    "default_registry": "hub.docker.com/u/<user>",
    "enable_providers": ["docker", "kubeadm-bootstrap", "kubeadm-control-plane"]
}
```

## Running the tilt environment

Run the tilt environment from your local copy of cluster api repo using the following command:

```bash
tilt up
```

This will open the command-line HUD as well as a web browser interface. You can monitor Tilt’s status in either location. After a brief amount of time, you should have a running development environment, and you should now be able to create a cluster.

## Create cluster

In this folder you can find example .yaml files to run simple cluster for testing cluster api. First you need to create a **cluster** for your workflow cluster. CAPD is creating load-balancer container for the cluster, as it will be creating containers for all cluster resources.

Create the cluster with:

```bash
kubectl apply -f cluster.yaml
```

Make sure cluster is provisioned.

```bash
kubectl get cluster
```

## Create control plane

Next create 3 KubeadmControlPlanes with:

```bash
kubectl apply -f controlplane.yaml
```

Provisioning of the control planes will take time, cause they are created one-by-one. You can see the status of the deployment with:

```bash
kubectl get kcp
```

When provisioning is done. You should see:

```bash
NAME              READY   INITIALIZED   REPLICAS   READY REPLICAS   UPDATED REPLICAS   UNAVAILABLE REPLICAS
my-controlplane           true          3                           3                  3
```

## Copy working cluster Kubeconfig

After the control plane node is up, you have to retrieve and save the working cluster Kubeconfig:

```bash
kubectl --namespace=default get secret/my-cluster-kubeconfig -o json | jq -r .data.value | base64 --decode > ./capi-kubeconfig
```

## Install and patch Calico

In this example we deploy Calico CNI solution. Deploy Calico using **capi-kubeconfig** copied in last step with:

```bash
kubectl --kubeconfig=capi-kubeconfig apply -f https://docs.projectcalico.org/v3.12/manifests/calico.yaml
```

After installation you need to patch Calico deployment to avoid issues with Docker provider.

```bash
kubectl --kubeconfig=./capi-kubeconfig \
  -n kube-system patch daemonset calico-node \
  --type=strategic --patch='
spec:
  template:
    spec:
      containers:
      - name: calico-node
        env:
        - name: FELIX_IGNORELOOSERPF
          value: "true"
'
```

When Calico is patched KCP should get into ready state.

```bash
NAME              READY   INITIALIZED   REPLICAS   READY REPLICAS   UPDATED REPLICAS   UNAVAILABLE REPLICAS
my-controlplane   true        true          3          3                3
```

## Create machinedeployment

Finishing up the test cluster, create 3 node machinedeployment with:

```bash
kubectl apply -f machine-deployment.yaml
```

You can follow the status of the deployment with:

```bash
kubectl get machinedeployment
```

When deployment is done, you should see:

```bash
NAME     PHASE     REPLICAS   AVAILABLE   READY
worker   Running   3          3           3
```

## Docker cluster

Now you have created test cluster. If you are interested to see containers running your cluster run `docker ps`.
