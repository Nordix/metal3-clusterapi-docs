# Container privileges, capabilities and users

Running containers as non-root (ie. without unneeded capabilities) is de facto security practise
to reduce attack surface. Default user can be set during the container build, and the user and
capabilities and other security context can be set runtime. In addition, host networking is checked
as that exposes other services on the host to the container.

## Security configurations

This table was created from the following releases:

* CAPM3: `release-1.4`
* Baremetal Operator: `v0.3.0`
* Ironic: `capm3-v1.4.0`
* CAPI: `v1.4.2`

### CAPM3 and IPAM

`capm3-system` namespace:

| Image | Name | Namespace | User | Container SecurityContext | Capabilities | Deployment SecurityContext | Host Network |
|---|---|---|---|---|---|---|---|
| `quay.io/metal3-io/cluster-api-provider-metal3:v1.4.0`|  `manager`| `capm3-system` | `65532` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||
| `quay.io/metal3-io/ip-address-manager:v1.4.0` | `manager` | `capm3-system` | `65532` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||

### BMO and Ironic

 `baremetal-operator-system` namespace:

| Image | Name | Namespace | User | Container SecurityContext | Capabilities | Deployment SecurityContext | Host Network |
|---|---|---|---|---|---|---|---|
| `quay.io/metal3-io/baremetal-operator:v0.3.0` | `manager` | `baremetal-operator-system` | `65532` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||
| `quay.io/metal3-io/ironic:capm3-v1.4.0` | `ironic` | `baremetal-operator-system` | `ironic` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | `true` |
| `quay.io/metal3-io/ironic:capm3-v1.4.0` | `ironic-httpd` | `baremetal-operator-system` | `ironic` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | `true` |
| `quay.io/metal3-io/ironic:capm3-v1.4.0`| `ironic-inspector` | `baremetal-operator-system` | `ironic-inspector` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | `true` |
| `quay.io/metal3-io/ironic:capm3-v1.4.0` | `ironic-dnsmasq` | `baremetal-operator-system` | `ironic` | `allowPrivilegeEscalation: true`, `privileged: false` | `drop: ALL`, `NET_ADMIN`, `NET_RAW`, `NET_BIND_SERVICE`  | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | `true` |
| `quay.io/metal3-io/ironic:capm3-v1.4.0` | `ironic-log-watch` | `baremetal-operator-system` | `ironic` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | `true` |
| `quay.io/metal3-io/keepalived:capm3-v1.4.0` | `ironic-endpoint-keepalived` | `baremetal-operator-system` | `65532` | `allowPrivilegeEscalation: true`, `privileged: false` | `drop: ALL`, `CAP_NET_ADMIN`, `CAP_NET_RAW`, `CAP_NET_BROADCAST` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | `true` |
| `quay.io/metal3-io/mariadb:capm3-v1.4.0` (optional container) | `mariadb` | `baremetal-operator-system` | `ironic` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | `true` |
| `quay.io/metal3-io/ironic-ipa-downloader:latest` | init container | `baremetal-operator-system` | `ironic` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` | `true` |

### CAPI

`capi-system`, `capi-kubeadm-bootstrap-system`,
`capi-kubeadm-control-plane-system` and `cert-manager` namespaces:

| Image | Name | Namespace | User | Container SecurityContext | Capabilities | Deployment SecurityContext | Host Network |
|---|---|---|---|---|---|---|---|
| `registry.k8s.io/cluster-api/kubeadm-bootstrap-controller:v1.4.2` | `manager` | `capi-kubeadm-bootstrap-system` | `65532` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||
| `registry.k8s.io/cluster-api/kubeadm-control-plane-controller:v1.4.2` | `manager`| `capi-kubeadm-control-plane-system` | `65532` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||
| `registry.k8s.io/cluster-api/cluster-api-controller:v1.4.2` | `manager` | `capi-system` | `65532` | `allowPrivilegeEscalation: false`, `privileged: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||
| `quay.io/jetstack/cert-manager-controller:v1.11.1` | `cert-manager-controller`| `cert-manager` | `1000` | `allowPrivilegeEscalation: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||
| `quay.io/jetstack/cert-manager-cainjector:v1.11.1` | `cert-manager-cainjector`| `cert-manager` | `1000` | `allowPrivilegeEscalation: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||
| `quay.io/jetstack/cert-manager-webhook:v1.11.1` | `cert-manager-webhook`| `cert-manager` | `1000` | `allowPrivilegeEscalation: false` | `drop: ALL` | `runAsNonRoot: true`, `seccompProfile: RuntimeDefault` ||
