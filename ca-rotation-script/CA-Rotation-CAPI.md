# Introduction

The purpose of this document is to provide step-by-step instructions how to do CA rotation on CAPI. For the remainder of this document, we use Kind as the management cluster and Cluster API Provider Docker (CAPD) as the infrastructure provider.

- Manually rotate CA in the workload cluster: [1][1]
- Update the management (CAPI) cluster secrets so it can interact with the workload cluster without any TLS problems.

## Prerequisites

- Go version 1.13.0+
- Docker
- Kind v0.6 or v0.7 (other clusters can be used if preload_images_for_kind is set to false)

## How to do

### Setup the management cluster and workload cluster

Firstly, install `clusterctl`. `v0.3.14` is used in the experiments in this document. The instruction can be found in <https://cluster-api.sigs.k8s.io/user/quick-start.html>

```sh
clusterctl version # Ensure that clusterctl is installed correctly
```

Then, create a kind cluster:

```sh
cat > kind-cluster-with-extramounts.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts: # This mount ensures that any CAPI pods inside this kind cluster can interact with the docker socker of the host
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
EOF

kind create cluster --config kind-cluster-with-extramounts.yaml
```

Next, initialize the management cluster by transforming the kind cluster into a management cluster:

```sh
clusterctl init --infrastructure docker
```

After that, create the workload cluster:

```sh
kubectl apply -f self-hosted-cluster-template.yaml
```

Note that if some objects cannot be created, that means the management cluster is not fully initialized. Wait for a few seconds then try the above command again.

Next, extract the kubeconfig of the workload cluster:

```sh
clusterctl get kubeconfig my-cluster > capi-kubeconfig
```

In this example, we deploy Calico CNI solution. Deploy Calico using capi-kubeconfig copied in the last step with:

```sh
kubectl --kubeconfig=capi-kubeconfig apply -f https://docs.projectcalico.org/v3.15/manifests/calico.yaml
```

Then, wait until all KCP and worker nodes are ready:

```sh
$ kubectl get kcp
NAME              READY   INITIALIZED   REPLICAS   READY REPLICAS   UPDATED REPLICAS   UNAVAILABLE REPLICAS
my-controlplane           true          1          1                1

$ kubectl get machinedeployment
NAME     PHASE     REPLICAS   AVAILABLE   READY
worker   Running   1          1           1
```

### Pivoting

If we want to make sure that the CA rotation procedure works with the case that the cluster is self-hosted, we have to do pivoting.

Firstly, initialize the CAPI and infrastructure provider components on the workload cluster:

```sh
clusterctl init --kubeconfig capi-kubeconfig --infrastructure docker
```

Next, move all CAPI components from the original management cluster to the workload cluster:

```sh
clusterctl move --to-kubeconfig capi-kubeconfig
```

Then, make sure that all KCP nodes and machine deployment nodes are in the ready state.

### CA rotation

Manually rotate the CA of the cluster following this [instruction][1]. In addition, A script is provided in the `script/` directory to do the CA rotation for the workload in this document:

```sh
cd script/
./manual-CA-Rotation.sh true # Whether to backup the /etc/kubernetes directory in the controlplane or not.
```

Finally, update the following secrets, so the CAPI components change to use the new CA:

- `<workload-cluster-name>-ca`:

```sh
$ kubectl get secret <workload-cluster-name>-ca -oyaml
apiVersion: v1
data:
  tls.crt: <Put the new base64-encoded CA certificate to replace the old one>
  tls.key: <Put the new base64-encoded CA key to replace the old one>
  ...
```

- `<workload-ckuster-name>-kubeconfig`:

```sh
$ kubectl get secret <workload-clsuter-name>-kubeconfig -oyaml
apiVersion: v1
data:
  value: <Convert the content of the new kubeconfig file (/etc/kubernetes/admin.conf) to base64 code and put it here>
  ...
```

- `<workload-cluster-name>-proxy`:

```sh
$ kubectl get secret <workload-cluster-name>-proxy -oyaml
apiVersion: v1
data:
  tls.crt: <Put the new base64-encoded front-peoxy-ca.crt here>
  tls.key: <Put the new base64-encoded front-peoxy-ca.key here>
```

After this step, the cluster should trust the new CA and no longer trust the old CA.

[1]: https://kubernetes.io/docs/tasks/tls/manual-rotation-of-ca-certificates/
