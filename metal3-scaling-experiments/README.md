# Scaling experiments

**Goal:** To run 1000 single node workload clusters managed by 1 management cluster with 3 control plane nodes.
It should be possible to create and destroy the clusters.
All workload clusters should be in separate namespaces.

- ✅ Create 3-node kind cluster
- ✅ Run BMO in test-mode (in cluster)
- ✅ Script setup of management cluster
- ✅ Script creation of workload clusters
- ✅ Scale to 300 clusters
- ✅ Scale to 1000 clusters
- ✅ Test larger cloud-init to check how etcd handles it
   - There seems to be no issues when testing with a 30kB file added in `KCP.spec.kubeadmConfigSpec.files`

*Note:* You will need to increase inotify limits for this to work.
See <https://cluster-api.sigs.k8s.io/user/troubleshooting.html#cluster-api-with-docker----too-many-open-files>

*Note:* This requires kind, kubeadm, clusterctl, kubectl and jq to be installed.
One way to ensure you have all requirements installed is to use a [devcontainer](https://containers.dev/) built from `.devcontainer/devcontainer.json`.
VS Code has support for devcontainers built in.
All you have to do is to open this folder in VS Code, then press Ctrl + Shift + P and search for the command "Open folder in dev container".

## Simulation setup

### Version 1

1. Create a kind cluster, initialize Cluster API and Metal3 with BMO in test-mode. Create the first workload cluster.
   `./setup-scaling-experiment.sh`
2. Add more workload clusters:
   `./create-clusters.sh <number-of-clusters>`

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

### Version 2

1. Create a kind cluster, initialize Cluster API and Metal3 with BMO in test-mode. Create the multi-tenant ETCD instance.
   `./setup-scaling-experiment-v2.sh`
2. Add more workload clusters:
   `./create-clusters-v2.sh <number-of-clusters>`

To solve the issues with version 1, this setup creates one API server per workload cluster, all backed by one multi-tenant etcd instance.
This simulation is much more realistic as each cluster has its own API and do not see each others Nodes or Pods.
However, running one API server per cluster takes a lot of resources.
Each one needs roughly 200 Mi memory, so scaling to 1000 clusters would require at least 200 Gi memory just for the API servers.

### Version 3 - External backing clusters

- Setup a (kind) cluster on an external machine and expose it in some way so that the test machine can reach it.
  See the `ansible` folder for a useful playbook that can help with this.
- `./setup-scaling-experiment-v3.sh` on the test machine
- For each backing cluster:
   - Set KUBECONFIG to point to the external cluster and run `./setup-backing-cluster.sh`.
     This will create one multi-tenant etcd in the backing cluster
- `./create-clusters-v3.sh <number-of-clusters> <kubeconfig> <start>`
   This will create `<number-of-clusters>` with the backing cluster that `<kubeconfig>` points to starting with cluster number `<start>`. (The starting number is to avoid collisions when using multiple backing clusters, since all cluster objecs live in the management cluster.) E.g. `./create-clusters-v3.sh 100 kubeconfig-backing-2.yaml 101`.

For scaling to 1000, I have done the following also:

- Set all concurrency flags to 100 (default is 10) for the CAPI controllers.
- Set a higher rate limit (200 QPS and 300 burst) for all the CAPI controllers (default is 20 QPS and 30 burst).
- Create 10 backing clusters for 100 workload clusters each. The backing clusters were set up with `setup-backing-cluster.sh` on VMs with 8 vCPUs and 32 GB RAM.

I have done these changes directly in the code/manifests and then set up tilt (see section below about tilt) so that they were automatically applied in the cluster directly.
The patch with the exact changes can be seen in `rate-limit-concurrency.patch`.

### Scripts

- `produce-hosts.sh`: Generate BareMetalHosts with provisioning information (they will be come provisioned).
- `produce-available-hosts.sh`: Generate BareMetalHosts that will become available (useful for Metal3).
- `setup-scaling-experiment.sh`: Create a KinD cluster, initialize the Metal3 stack and create one workload cluster.
- `setup-scaling-experiment-v2.sh`: Similar to above, but with multi-tenant etcd and one API server per workload cluster.
- `setup-scaling-experiment-v3.sh`: Similar to above, but for use with external backing clusters (where the workload clusters API servers and ETCD instances run).
- `setup-backing-cluster.sh`: Initialize a backing cluster with a central ETCD instance and the necessary certificates.
- `create-clusters.sh`: Create additional single node workload clusters.
- `create-clusters-v2.sh`: Similar to above but for one API server per workload cluster.
- `create-clusters-v3.sh`: Similar to above but for external backing clusters.
- `create-clusters-sharded.sh`: Create additional single node workload clusters sharded so that each shard has its own namespace and KubeadmControlPlane provider.
- `delete-clusters.sh`: Delete clusters created by `create-clusters.sh`.
- `delete-clusters-v2.sh` Similar to above but for `create-clusters-v2.sh`.
- `delete-clusters-v3.sh` Similar to above but for `create-clusters-v3.sh`.
- `delete-clusters-sharded.sh`: Delete clusters created by `create-clusters-sharded.sh`.
- `fake-controller.sh`: Create fake worker nodes on demand for the workload cluster. Useful for scaling MachineDeployment.

## Notes

### Performance and metrics

Set concurrency:

```bash
kubectl patch -n capi-kubeadm-control-plane-system deployment \
  capi-kubeadm-control-plane-controller-manager --type=json \
  -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubeadmcontrolplane-concurrency=100"}]'
```

- Install metrics-server:

  ```bash
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
  kubectl patch -n kube-system deployment metrics-server --type=json -p '[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
  ```

- Version 3
   - Scale 0-100 in ~10 minutes.
   - Scale 100-200 in ~15 minutes.
   - Scale 200-300 in ~35 minutes.
   - Scale 300-400 in ~30 minutes.
   - Scale 400-500 in ~50 minutes.
   - Scale 500-600 in ~15 minutes with concurrency set to 100.
   - Scale 600-700 in ~165 minutes.
   - With higher rate limits and concurrency for CAPI. Management cluster running on 32C-64GB VM.
      - Scale 0-100 in ~10 minutes.
      - Scale 100-200 in ~10 minutes.
      - Scale 200-300 in ~15 minutes.
      - Scale 300-400 in ~20 minutes.
      - Scale 400-500 in ~25 minutes.
      - Scale 500-600 in ~30 minutes.
      - Scale 600-700 in ~30 minutes.
      - Scale 700-800 in ~35 minutes.
      - Scale 800-900 in ~35 minutes.
      - Scale 900-1000 in ~45 minutes. 🎉
- Version 2
   - Scale to 100 clusters in ~10 minutes.
   - Scale to 150 clusters in ~15 minutes.
   - Scale to 200 clusters in ~20 minutes.
- Management cluster KinD, 3 control plane nodes, adding 10 clusters at a time.
   - External ETCD: Scale to 100 clusters in ~15 minutes.
   - Internal ETCD: Scale to 100 clusters in ~30 minutes.
   - External ETCD: Scale to 300 clusters in ~135 minutes.
      - Adding just 1 cluster more at this scale takes more than 8 minutes.
   - External ETCD:
      - KubeadmControlPlane provider concurrency set to 100: Scale to 300 clusters in ~70 minutes.
         - Adding 1 cluster takes ~8 minutes.
      - KubeadmControlPlane provider concurrency set to 500: Scale to 300 clusters in ~74 minutes.
         - Adding 1 cluster takes ~4 minutes.
         - Scale from 300 to 500 in ~120 minutes.
            - Adding 1 cluster takes ~6.5 minutes.
         - Scale to 1000 clusters in ~22.5 hours.
- Single node management cluster, adding 10 clusters at a time.
   - External ETCD: Scale to 100 clusters in ~15 minutes.
- CAPD: 20 clusters in ~5 minutes.
   - 50 clusters is already hitting limits of 32 GB machine. This way of scaling will require a lot of resources.

#### Resource usage in the management cluster for version 3

Earlier metrics removed since they were inaccurate due to the experimental setup.

Idle at 1000 clusters:

```console
❯ kubectl top pods -A
NAMESPACE                           NAME                                                             CPU(cores)   MEMORY(bytes)
baremetal-operator-system           baremetal-operator-controller-manager-64c5489695-n9bhp           35m          76Mi
capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-controller-manager-c99b96648-rprvr        104m         71Mi
capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-controller-manager-7c5fc49c58-4qm6r   16531m       1898Mi
capi-system                         capi-controller-manager-5cf7775bb4-68sr4                         2525m        1322Mi
capm3-system                        capm3-controller-manager-669989d4-w6st2                          454m         352Mi
capm3-system                        ipam-controller-manager-65fc446776-8pcfk                         2m           15Mi
cert-manager                        cert-manager-99bb69456-rs2z7                                     1m           84Mi
cert-manager                        cert-manager-cainjector-ffb4747bb-bqws7                          2m           157Mi
cert-manager                        cert-manager-webhook-545bd5d7d8-5b5cp                            1m           12Mi
kube-system                         coredns-565d847f94-4bhsl                                         3m           16Mi
kube-system                         coredns-565d847f94-zk9m2                                         4m           15Mi
kube-system                         etcd-kind-control-plane                                          576m         241Mi
kube-system                         etcd-kind-control-plane2                                         296m         234Mi
kube-system                         etcd-kind-control-plane3                                         414m         227Mi
kube-system                         kindnet-6f78x                                                    1m           8Mi
kube-system                         kindnet-bgzxj                                                    1m           9Mi
kube-system                         kindnet-tdxk6                                                    1m           10Mi
kube-system                         kube-apiserver-kind-control-plane                                3559m        4418Mi
kube-system                         kube-apiserver-kind-control-plane2                               950m         4255Mi
kube-system                         kube-apiserver-kind-control-plane3                               1935m        4241Mi
kube-system                         kube-controller-manager-kind-control-plane                       2m           16Mi
kube-system                         kube-controller-manager-kind-control-plane2                      81m          343Mi
kube-system                         kube-controller-manager-kind-control-plane3                      2m           16Mi
kube-system                         kube-proxy-bs2th                                                 1m           12Mi
kube-system                         kube-proxy-f2pbc                                                 1m           12Mi
kube-system                         kube-proxy-rn5hl                                                 1m           12Mi
kube-system                         kube-scheduler-kind-control-plane                                4m           18Mi
kube-system                         kube-scheduler-kind-control-plane2                               4m           19Mi
kube-system                         kube-scheduler-kind-control-plane3                               4m           21Mi
kube-system                         metrics-server-55dd79d7bf-tcfj7                                  6m           19Mi
local-path-storage                  local-path-provisioner-684f458cdd-dqs6c                          1m           7Mi
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

## Debugging with tilt

Tilt-settings:

```yaml
default_registry: gcr.io/cluster-api-provider
kind_cluster_name: kind
enable_providers:
- kubeadm-bootstrap
- kubeadm-control-plane
```

```bash
# After creating the experiment environment
export CAPI_KIND_CLUSTER_NAME=kind
make tilt-up
```

### Certificate annotation rollout issue

Rollout caused by `MatchesKubeadmBootstrapConfig(machineConfigs, kcp)`
**The rolling KCPs has kubeadm join configuration *instead* of init configuration.**
This can be seen by checking the secret containing the kubeadm bootstrap data.

```bash
kubectl -n test-11 get secret test-11-h7kmr -o jsonpath="{.data.value}" | base64 -d
# KCPs that rollout has the file /run/kubeadm/kubeadm-join-config.yaml
# But those that do not rollout instead has /run/kubeadm/kubeadm.yaml
kubectl -n test-11 get secret test-11-h7kmr -o jsonpath="{.data.value}" | base64 -d | yq '.write_files[] | select(.path == "/run/kubeadm/kubeadm.yaml") | .content' | yq
kubectl -n test-11 get secret test-11-h7kmr -o jsonpath="{.data.value}" | base64 -d | yq '.write_files[] | select(.path == "/run/kubeadm/kubeadm-join-config.yaml") | .content' | yq
```

Relevant code: <https://github.com/kubernetes-sigs/cluster-api/blob/87b19f55d71c431b624599d2f3a845ae955a09ee/controlplane/kubeadm/internal/controllers/controller.go#L396-L413>

### Concurrency and Rate Limits

All CAPI controllers has configurable concurrency (default 10), but CAPM3 is lacking this (currently set to 1).
Relevant code in CAPI: <https://github.com/kubernetes-sigs/cluster-api/blob/d0bd60c23f87a6238a0ae048659ad800e774f81a/controlplane/kubeadm/main.go#L299>

None of the controllers has configurable rate limits.
The [default in client-go is 10 qps](https://github.com/kubernetes/client-go/blob/02d652e007235a5b46b9972bf136f274983853e6/util/workqueue/default_rate_limiters.go#L39) but the [default in controller-runtime is 20 qps](https://github.com/kubernetes-sigs/controller-runtime/blob/v0.14.5/pkg/client/config/config.go#L96), which is probably where the controllers gets their defaults.
See also <https://pkg.go.dev/k8s.io/client-go/util/flowcontrol#RateLimiter>

This is likely impacting performance.
See for example this log from the kubeadm control plane controller:

```text
I0302 15:50:57.343130       1 request.go:601] Waited for 4.870221494s due to client-side throttling, not priority and fairness, request: GET:https://10.96.0.1:443/api/v1/namespaces/test-697/secrets/test-697-sa
```

### Custom resources limits and scale targets

See <https://github.com/kubernetes/enhancements/tree/master/keps/sig-api-machinery/95-custom-resource-definitions#scale-targets-for-ga>

TODO:

- Add support for setting concurrency in CAPM3
- Add support for configuring the RateLimit
- Investigate why the KCP controller is using so much CPU
- Redo the experiment with all the above to see how much the speed and resource utilization improved.
