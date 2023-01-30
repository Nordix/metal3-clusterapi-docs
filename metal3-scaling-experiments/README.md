# Scaling experiments

**Goal:** To run 1000 single node workload clusters managed by 1 management cluster with 3 control plane nodes.
It should be possible to create and destroy the clusters.
All workload clusters should be in separate namespaces.

- ✅ Create 3-node kind cluster
- ✅ Run BMO in test-mode (in cluster)
- ✅ Script setup of management cluster
- ✅ Script creation of workload clusters
- ✅ Scale to 300 clusters
- ❌ Scale to 1000 clusters - Not attempted
- ✅ Test larger cloud-init to check how etcd handles it
   - There seems to be no issues when testing with a 30kB file added in `KCP.spec.kubeadmConfigSpec.files`

*Note:* You will need to increase inotify limits for this to work.
See <https://cluster-api.sigs.k8s.io/user/troubleshooting.html#cluster-api-with-docker----too-many-open-files>

*Note:* This requires kind, kubeadm, clusterctl, kubectl and jq to be installed.
One way to ensure you have all requirements installed is to use a [devcontainer](https://containers.dev/) built from `.devcontainer/devcontainer.json`.
VS Code has support for devcontainers built in.
All you have to do is to open this folder in VS Code, then press Ctrl + Shift + P and search for the command "Open folder in dev container".

1. Create a kind cluster, initialize Cluster API and Metal3 with BMO in test-mode. Create the first workload cluster.
   `./setup-scaling-experiment.sh`
2. Add more workload clusters:
   `./create-clusters.sh <number-of-clusters>`

## Simulation setup

To avoid running into resource constraints we have been running BMO in test-mode and set up a single API server to fake all workload clusters.
With this setup we can get the Machines, Metal3Machines, BareMetalHosts fully healthy.
The KubeadmControlPlanes are harder, they are not fully "convinced" of the simulation and this could affect the results.
The simulation environment is made up like this:

- Management cluster: A normal KinD cluster with 3 nodes
- CAPI + CAPM3 are installed using `clusterctl` as normal
- BMO is deployed using static manifests, configured to run in test-mode.
- The workload cluster's API are faked by a k8s API server and etcd pod running in the management cluster (one kube-apiserver pod for all the workload clusters)
- For each cluster
   - The cluster, KCP, BMH and relevant templates are created
   - Pre-generated CAs for etcd and k8s are added (this is for faking the workload cluster API server)
   - (optional) Pre-generated etcd client certificate is also added. This is for running in external etcd mode, which helps speed things up a bit.
   - The workload cluster (fake) node is added to the workload cluster API with correct provider ID
   - The workload cluster static pods (fake) are added to the workload cluster API

Caveats:

- Since all workload clusters share one API, they will be able to see each others nodes.
  This makes the KCPs a bit "confused" since they see nodes that does not have correlated Machines.
- The Kubeadm control plane provider is trying to reach the (fake) static pods to check certificate expiration.
  To try to mitigate this, we attempted to set the expiration annotation on the KubeadmConfig, but unfortunately this caused some KCPs to start rollouts. It is unclear what is causing this.

### Scripts

- `produce-hosts.sh`: Generate BareMetalHosts with provisioning information (they will be come provisioned).
- `produce-available-hosts.sh`: Generate BareMetalHosts that will become available (useful for Metal3).
- `setup-scaling-experiment.sh`: Create a KinD cluster, initialize the Metal3 stack and create one workload cluster.
- `create-clusters.sh`: Create additional single node workload clusters.
- `create-clusters-sharded.sh`: Create additional single node workload clusters sharded so that each shard has its own namespace and KubeadmControlPlane provider.
- `delete-clusters.sh`: Delete clusters created by `create-clusters.sh`.
- `delete-clusters-sharded.sh`: Delete clusters created by `create-clusters-sharded.sh`.
- `fake-controller.sh`: Create fake worker nodes on demand for the workload cluster. Useful for scaling MachineDeployment.

## Notes

### Performance and metrics

- Install metrics-server:

  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl patch -n kube-system deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  ```

- Management cluster KinD, 3 control plane nodes, adding 10 clusters at a time.
   - External ETCD: Scale to 100 clusters in ~15 minutes.
   - Internal ETCD: Scale to 100 clusters in ~30 minutes.
   - External ETCD: Scale to 300 clusters in ~135 minutes.
      - Adding just 1 cluster more at this scale takes more than 8 minutes.
- Single node management cluster, adding 10 clusters at a time.
   - External ETCD: Scale to 100 clusters in ~15 minutes.
- CAPD: 20 clusters in ~5 minutes.
   - 50 clusters is already hitting limits of 32 GB machine. This way of scaling will require a lot of resources.

Resource usage in the management cluster while creating workload clusters (~180 created):

```console
vscode ➜ /workspaces/baremetal-operator (lentzi90/scaling-experiments ✗) $ k top pods -A
NAMESPACE                           NAME                                                             CPU(cores)   MEMORY(bytes)
baremetal-operator-system           baremetal-operator-controller-manager-5b9bb4747-pj68b            3m           34Mi
capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-controller-manager-78c76cd689-7ng2z       3m           44Mi
capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-controller-manager-785c94c5d4-64f45   548m         730Mi
capi-system                         capi-controller-manager-7b6df78867-4nj7k                         207m         761Mi
capm3-system                        capm3-controller-manager-669989d4-9lp4m                          289m         80Mi
capm3-system                        ipam-controller-manager-65fc446776-qv99w                         2m           15Mi
cert-manager                        cert-manager-74d949c895-b2vlw                                    1m           48Mi
cert-manager                        cert-manager-cainjector-d9bc5979d-8dst8                          1m           51Mi
cert-manager                        cert-manager-webhook-84b7ddd796-qt6vn                            1m           12Mi
kube-system                         coredns-565d847f94-2b9cx                                         5m           18Mi
kube-system                         coredns-565d847f94-7jqnv                                         5m           19Mi
kube-system                         etcd-kind-control-plane                                          194m         146Mi
kube-system                         etcd-kind-control-plane2                                         194m         132Mi
kube-system                         etcd-kind-control-plane3                                         127m         134Mi
kube-system                         kindnet-9vpgt                                                    1m           12Mi
kube-system                         kindnet-jzthr                                                    1m           12Mi
kube-system                         kindnet-nkkdf                                                    1m           10Mi
kube-system                         kube-apiserver-kind-control-plane                                544m         1313Mi
kube-system                         kube-apiserver-kind-control-plane2                               381m         1161Mi
kube-system                         kube-apiserver-kind-control-plane3                               177m         1076Mi
kube-system                         kube-controller-manager-kind-control-plane                       28m          102Mi
kube-system                         kube-controller-manager-kind-control-plane2                      2m           22Mi
kube-system                         kube-controller-manager-kind-control-plane3                      2m           23Mi
kube-system                         kube-proxy-bqmjk                                                 1m           19Mi
kube-system                         kube-proxy-crgzb                                                 1m           12Mi
kube-system                         kube-proxy-zwvwh                                                 1m           13Mi
kube-system                         kube-scheduler-kind-control-plane                                3m           19Mi
kube-system                         kube-scheduler-kind-control-plane2                               3m           23Mi
kube-system                         kube-scheduler-kind-control-plane3                               2m           21Mi
kube-system                         metrics-server-55dd79d7bf-fqsxl                                  4m           17Mi
local-path-storage                  local-path-provisioner-684f458cdd-2qmkv                          1m           7Mi
metal3                              etcd-0                                                           14m          35Mi
metal3                              test-kube-apiserver-69dd6dd947-b7zkn                             111m         375Mi
```

Resource usage "idle" at 200 workload clusters:

```console
vscode ➜ /workspaces/baremetal-operator (lentzi90/scaling-experiments ✗) $ k top pods -A
NAMESPACE                           NAME                                                             CPU(cores)   MEMORY(bytes)
baremetal-operator-system           baremetal-operator-controller-manager-5b9bb4747-pj68b            4m           33Mi
capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-controller-manager-78c76cd689-7ng2z       2m           41Mi
capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-controller-manager-785c94c5d4-64f45   481m         861Mi
capi-system                         capi-controller-manager-7b6df78867-4nj7k                         189m         887Mi
capm3-system                        capm3-controller-manager-669989d4-9lp4m                          227m         86Mi
capm3-system                        ipam-controller-manager-65fc446776-qv99w                         1m           15Mi
cert-manager                        cert-manager-74d949c895-b2vlw                                    1m           49Mi
cert-manager                        cert-manager-cainjector-d9bc5979d-8dst8                          1m           53Mi
cert-manager                        cert-manager-webhook-84b7ddd796-qt6vn                            1m           13Mi
kube-system                         coredns-565d847f94-2b9cx                                         5m           19Mi
kube-system                         coredns-565d847f94-7jqnv                                         6m           19Mi
kube-system                         etcd-kind-control-plane                                          161m         168Mi
kube-system                         etcd-kind-control-plane2                                         164m         154Mi
kube-system                         etcd-kind-control-plane3                                         100m         157Mi
kube-system                         kindnet-9vpgt                                                    1m           12Mi
kube-system                         kindnet-jzthr                                                    1m           12Mi
kube-system                         kindnet-nkkdf                                                    1m           10Mi
kube-system                         kube-apiserver-kind-control-plane                                476m         1319Mi
kube-system                         kube-apiserver-kind-control-plane2                               367m         1220Mi
kube-system                         kube-apiserver-kind-control-plane3                               172m         1203Mi
kube-system                         kube-controller-manager-kind-control-plane                       26m          107Mi
kube-system                         kube-controller-manager-kind-control-plane2                      2m           22Mi
kube-system                         kube-controller-manager-kind-control-plane3                      1m           23Mi
kube-system                         kube-proxy-bqmjk                                                 1m           19Mi
kube-system                         kube-proxy-crgzb                                                 1m           12Mi
kube-system                         kube-proxy-zwvwh                                                 1m           13Mi
kube-system                         kube-scheduler-kind-control-plane                                3m           19Mi
kube-system                         kube-scheduler-kind-control-plane2                               2m           23Mi
kube-system                         kube-scheduler-kind-control-plane3                               2m           21Mi
kube-system                         metrics-server-55dd79d7bf-fqsxl                                  5m           18Mi
local-path-storage                  local-path-provisioner-684f458cdd-2qmkv                          1m           7Mi
metal3                              etcd-0                                                           13m          36Mi
metal3                              test-kube-apiserver-69dd6dd947-b7zkn                             121m         384Mi
```

Idle at 300 clusters:

```console
vscode ➜ /workspaces/baremetal-operator (lentzi90/scaling-experiments ✗) $ k top pods -A
NAMESPACE                           NAME                                                             CPU(cores)   MEMORY(bytes)
baremetal-operator-system           baremetal-operator-controller-manager-5b9bb4747-kwzpb            6m           36Mi
capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-controller-manager-78c76cd689-8jz54       2m           40Mi
capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-controller-manager-77c89fc5bc-tl7w4   968m         1736Mi
capi-system                         capi-controller-manager-7dc886bcd8-kwhmf                         127m         1720Mi
capm3-system                        capm3-controller-manager-669989d4-vn7dp                          61m          110Mi
capm3-system                        ipam-controller-manager-65fc446776-tvqrf                         2m           13Mi
cert-manager                        cert-manager-74d949c895-rdd86                                    1m           57Mi
cert-manager                        cert-manager-cainjector-d9bc5979d-drqxc                          2m           66Mi
cert-manager                        cert-manager-webhook-84b7ddd796-nq46l                            1m           10Mi
kube-system                         coredns-565d847f94-dvw8f                                         2m           15Mi
kube-system                         coredns-565d847f94-gw2hm                                         2m           15Mi
kube-system                         etcd-kind-control-plane                                          88m          159Mi
kube-system                         etcd-kind-control-plane2                                         87m          146Mi
kube-system                         etcd-kind-control-plane3                                         124m         148Mi
kube-system                         kindnet-jw7dd                                                    1m           8Mi
kube-system                         kindnet-l9hhh                                                    1m           8Mi
kube-system                         kindnet-lhn5z                                                    1m           8Mi
kube-system                         kube-apiserver-kind-control-plane                                125m         1379Mi
kube-system                         kube-apiserver-kind-control-plane2                               213m         1322Mi
kube-system                         kube-apiserver-kind-control-plane3                               172m         1310Mi
kube-system                         kube-controller-manager-kind-control-plane                       20m          122Mi
kube-system                         kube-controller-manager-kind-control-plane2                      1m           16Mi
kube-system                         kube-controller-manager-kind-control-plane3                      1m           16Mi
kube-system                         kube-proxy-kzj59                                                 1m           11Mi
kube-system                         kube-proxy-sm8c4                                                 1m           11Mi
kube-system                         kube-proxy-xvztx                                                 1m           11Mi
kube-system                         kube-scheduler-kind-control-plane                                3m           19Mi
kube-system                         kube-scheduler-kind-control-plane2                               2m           17Mi
kube-system                         kube-scheduler-kind-control-plane3                               2m           16Mi
kube-system                         metrics-server-55dd79d7bf-7xg5t                                  3m           21Mi
local-path-storage                  local-path-provisioner-684f458cdd-pwcfg                          1m           7Mi
metal3                              etcd-0                                                           11m          37Mi
metal3                              test-kube-apiserver-69dd6dd947-d6vfx                             135m         429Mi
```

### CAPD scaling for comparison

```bash
cat > kind-cluster-with-extramounts.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
- role: control-plane
  extraMounts:
      - hostPath: /var/run/docker.sock
        containerPath: /var/run/docker.sock
- role: control-plane
  extraMounts:
      - hostPath: /var/run/docker.sock
        containerPath: /var/run/docker.sock
EOF
kind create cluster --config kind-cluster-with-extramounts.yaml
kubectl taint node kind-control-plane node-role.kubernetes.io/control-plane-
kubectl taint node kind-control-plane2 node-role.kubernetes.io/control-plane-
kubectl taint node kind-control-plane3 node-role.kubernetes.io/control-plane-

export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure=docker
cluster_template="/tmp/cluster-template.yaml"
cluster_class="/tmp/cluster-class.yaml"
wget -O "${cluster_template}" "https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.3.2/cluster-template-development.yaml"
wget -O "${cluster_class}" "https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.3.2/clusterclass-quick-start.yaml"

cluster="test-1"
namespace="${cluster}"
kubectl create namespace "${namespace}"
kubectl -n "${namespace}" create -f "${cluster_class}"
clusterctl generate cluster "${cluster}" --from "${cluster_template}" --kubernetes-version v1.26.0 \
  --control-plane-machine-count=1 --worker-machine-count=0 --target-namespace "${namespace}" | kubectl apply -f -

num="100"
# Add more clusters in steps of step.
step="10"
for (( i = 1; i <= num; ++i )); do
  cluster="test-$i"
  namespace="${cluster}"
  kubectl create namespace "${namespace}"
  kubectl -n "${namespace}" create -f "${cluster_class}"
  clusterctl generate cluster "${cluster}" --from "${cluster_template}" --kubernetes-version v1.26.0 \
    --control-plane-machine-count=1 --worker-machine-count=0 --target-namespace "${namespace}" | kubectl apply -f -
  if (( $i % $step == 0 )); then
    echo "Waiting for $i clusters to be created in the background."
    # Wait for machine
    while [[ "$(kubectl -n "${namespace}" get machine -o jsonpath="{.items[0].status.phase}")" != "Running" ]] &> /dev/null; do
      # echo "Waiting for Machine to exist."
      sleep 5
    done
  fi
done
```

## Example run with only BMO

Setup cluster with CRDs and cert-manager.

```bash
kind create cluster
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.10.1/cert-manager.yaml
kubectl apply -k config/crd
```

Run BMO in test mode (in a separate terminal):

```bash
# If you use docker instead of podman, you need to set CONTAINER_RUNTIME=docker
CONTAINER_RUNTIME=docker make run-test-mode
```

Generate BareMetalHosts and secrets:

```bash
./produce-hosts.sh 3 > test-hosts.yaml
```

Apply and check result.

```bash
kubectl create namespace metal3
kubectl -n metal3 apply -f test-hosts.yaml
```

After a few seconds you can already see them going into `provisioned` state:

```console
$ kubectl -n metal3 get bmh
NAME       STATE          CONSUMER   ONLINE   ERROR   AGE
worker-1   provisioned               true             10s
worker-2   provisioning              true             10s
worker-3   provisioned               true             10s
```

## Scaling MachineDeployment with fake-controller

```bash
# Start the fake-controller in a separate terminal
./fake-controller.sh

# Scale the MD and watch the Machines successfully provision!
kubectl -n metal3 scale md test --replicas=x
```

Caveats:

- The KCP will have some issues since it is not "real", including unknown health for etcd and such.
  This also means that scaling the KCP does not work.
