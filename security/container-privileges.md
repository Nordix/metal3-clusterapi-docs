# Container privileges, capabilities and users

Running containers as non-root (ie. without unneeded capabilities) is de facto security practise
to reduce attack surface. Default user can be set during the container build, and the user and
capabilities and other security context can be set runtime. In addition, host networking is checked
as that exposes other services on the host to the container.

## Security configurations

This table was created from the following releases:

* CAPM3: `release-1.2`
* CAPI: `v1.3.0-beta1`
* Baremetal Operator: `v0.1.2`
* Ironic: `capm3-v1.2.1`

### CAPM3 and CAPI

| Image | Name | Namespace | User | SecurityContext | Capabilities  | Host Network |
|---|---|---|---|---|---|---|
| `registry.k8s.io/cluster-api/kubeadm-bootstrap-controller:v1.3.0-beta.1` | `manager` | `capi-kubeadm-bootstrap-system` |  `65532` |||
| `registry.k8s.io/cluster-api/kubeadm-control-plane-controller:v1.3.0-beta.1` | `manager`| `capi-kubeadm-control-plane-system` | `65532` |||
| `registry.k8s.io/cluster-api/cluster-api-controller:v1.3.0-beta.1` | `manager` | `capi-system` | `65532` |||
| `quay.io/metal3-io/cluster-api-provider-metal3:release-1.2`|  `manager`| `capm3-system` | `65532` |||
| `quay.io/metal3-io/ip-address-manager:release-1.2` | `manager` | `capm3-system` | `65532` |||
| `quay.io/jetstack/cert-manager-controller:v1.10.0` | `cert-manager-controller`| `cert-manager` | `1000` | `runAsNonRoot: true`, `allowPrivilegeEscalation: false` | `drop: ALL` |
| `quay.io/jetstack/cert-manager-cainjector:v1.10.0` | `cert-manager-cainjector`| `cert-manager` | `1000` | `runAsNonRoot: true`, `allowPrivilegeEscalation: false` | `drop: ALL` |
| `quay.io/jetstack/cert-manager-webhook:v1.10.0` | `cert-manager-webhook`| `cert-manager` | `1000` | `runAsNonRoot: true`, `allowPrivilegeEscalation: false` | `drop: ALL` |

### BMO and Ironic

| Image | Name | Namespace | User | SecurityContext | Capabilities  | Host Network |
|---|---|---|---|---|---|---|
| `quay.io/metal3-io/baremetal-operator:v0.1.2` | `manager` | `baremetal-operator-system` | `nonroot` | `allowPrivilegeEscalation: false` |||
| `gcr.io/kubebuilder/kube-rbac-proxy:v0.8.0` | `kube-rbac-proxy` | `baremetal-operator-system` |  `65532` |||
| `quay.io/metal3-io/ironic:capm3-v1.2.1` | `ironic` | `baremetal-operator-system` | `root` ||| `true` |
| `quay.io/metal3-io/ironic:capm3-v1.2.1` | `ironic-httpd` | `baremetal-operator-system` | `root` ||| `true` |
| `quay.io/metal3-io/ironic:capm3-v1.2.1`| `ironic-inspector` | `baremetal-operator-system` | `root` ||| `true` |
| `quay.io/metal3-io/ironic:capm3-v1.2.1` | `ironic-dnsmasq` | `baremetal-operator-system` | `root` || `NET_ADMIN`, `NET_RAW` | `true` |
| `quay.io/metal3-io/ironic:capm3-v1.2.1` | `ironic-log-watch` | `baremetal-operator-system` | `root` ||| `true` |
| `quay.io/metal3-io/keepalived` | `ironic-endpoint-keepalived` | `baremetal-operator-system` | `root` || `NET_ADMIN`, `NET_RAW` | `true` |
| `quay.io/metal3-io/mariadb` | `mariadb` | `baremetal-operator-system` | `root` ||| `true` |
| `quay.io/metal3-io/ironic-ipa-downloader` | init container | `baremetal-operator-system` | `root` ||| `true` |

### Development Environment

Kubernetes management cluster as launched by development environment on CentOS.

| Image | Name | Namespace | User | SecurityContext | Capabilities  | Host Network |
|---|---|---|---|---|---|---|
| `gcr.io/k8s-minikube/storage-provisioner:v5` | `storage-provisioner` | `kube-system` | `root` ||| `true` |
| `k8s.gcr.io/coredns/coredns:v1.8.6` | `coredns` | `kube-system` | `root` | `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` | `drop: ALL`, `NET_BIND_SERVICE` ||
| `k8s.gcr.io/etcd:3.5.1-0` | `etcd` | `kube-system` | `root` ||| `true` |
| `k8s.gcr.io/kube-apiserver:v1.23.3` | `kube-apiserver` | `kube-system` | `root` ||| `true` |
| `k8s.gcr.io/kube-controller-manager:v1.23.3` | `kube-controller-manager` | `kube-system` | `root` ||| `true` |
| `k8s.gcr.io/kube-proxy:v1.23.3` | `kube-proxy`| `kube-system` | `root` | `privileged: true` || `true` |
| `k8s.gcr.io/kube-scheduler:v1.23.3` | `kube-scheduler`| `kube-system` | `root` ||| `true` |
| `k8s.gcr.io/pause:3.6` | k8s pause container | `kube-system` | `65535` ||||
