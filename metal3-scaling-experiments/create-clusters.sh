#!/usr/bin/env bash

set -eu

CLUSTER_TEMPLATE=/tmp/cluster-template.yaml
export CLUSTER_APIENDPOINT_HOST="test-kube-apiserver.metal3.svc.cluster.local"
export CLUSTER_APIENDPOINT_PORT="6443"
# For external ETCD
export CTLPLANE_KUBEADM_EXTRA_CONFIG="
    clusterConfiguration:
      controlPlaneEndpoint: test-kube-apiserver.metal3.svc.cluster.local:6443
      apiServer:
        certSANs:
        - localhost
        - 127.0.0.1
        - 0.0.0.0
        - test-kube-apiserver.metal3.svc.cluster.local
      etcd:
        external:
          endpoints:
            - https://etcd-server.metal3.cluster.svc.local:2379
          caFile: /etc/kubernetes/pki/etcd/ca.crt
          certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
          keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key"
# For internal ETCD
# export CTLPLANE_KUBEADM_EXTRA_CONFIG="
#     clusterConfiguration:
#       controlPlaneEndpoint: test-kube-apiserver.metal3.svc.cluster.local:6443
#       apiServer:
#         certSANs:
#         - localhost
#         - 127.0.0.1
#         - 0.0.0.0
#         - test-kube-apiserver.metal3.svc.cluster.local
#       etcd:
#         local:
#           serverCertSANs:
#             - etcd-server.metal3.cluster.svc.local
#           peerCertSANs:
#             - etcd-0.etcd.metal3.cluster.svc.local"
export IMAGE_CHECKSUM="97830b21ed272a3d854615beb54cf004"
export IMAGE_CHECKSUM_TYPE="md5"
export IMAGE_FORMAT="raw"
export IMAGE_URL="http://172.22.0.1/images/rhcos-ootpa-latest.qcow2"
export KUBERNETES_VERSION="v1.25.3"
export WORKERS_KUBEADM_EXTRA_CONFIG=""

create_cluster() {
  cluster="${1:-test-1}"
  namespace="${2:-${cluster}}"

  echo "Creating cluster ${cluster} in namespace ${namespace}"

  # Create namespace and BMH
  kubectl create namespace "${namespace}"
  kubectl -n "${namespace}" apply -f /tmp/test-hosts.yaml

  # Upload same CA certs as used in the first cluster
  kubectl -n "${namespace}" create secret tls "${cluster}-etcd" --cert /tmp/pki/etcd/peer.crt --key /tmp/pki/etcd/peer.key
  kubectl -n "${namespace}" create secret tls "${cluster}-ca" --cert /tmp/pki/ca.crt --key /tmp/pki/ca.key
  # For external ETCD
  kubectl -n "${namespace}" create secret tls "${cluster}-apiserver-etcd-client" --cert /tmp/pki/apiserver-etcd-client.crt --key /tmp/pki/apiserver-etcd-client.key

  # Create cluster!
  clusterctl generate cluster "${cluster}" \
    --from "${CLUSTER_TEMPLATE}" \
    --target-namespace "${namespace}" | kubectl apply -f -

  # Wait for BMH to be available (or provisioned if rerunning the script)
  bmh_state="$(kubectl -n "${namespace}" get bmh -o jsonpath="{.items[0].status.provisioning.state}")"
  while [[ "${bmh_state}" != "available" ]] && [[ "${bmh_state}" != "provisioned" ]]; do
    # echo "Waiting for BMH to become available. bmh_state: ${bmh_state}"
    sleep 3
    bmh_state="$(kubectl -n "${namespace}" get bmh -o jsonpath="{.items[0].status.provisioning.state}")"
  done

  # Wait for machine
  while ! kubectl -n "${namespace}" get machine -o jsonpath="{.items[0].metadata.name}" &> /dev/null; do
    # echo "Waiting for Machine to exist."
    sleep 5
  done
  machine="$(kubectl -n "${namespace}" get machine -o jsonpath="{.items[0].metadata.name}")"

  # Wait for metal3machine
  while ! kubectl -n "${namespace}" get m3m -l cluster.x-k8s.io/cluster-name="${cluster}" -o jsonpath="{.items[0].metadata.name}" &> /dev/null; do
    # echo "Waiting for Metal3Machine to exist."
    sleep 5
  done
  metal3machine="$(kubectl -n "${namespace}" get m3m -l cluster.x-k8s.io/cluster-name="${cluster}" -o jsonpath="{.items[0].metadata.name}")"

  # Wait for metal3machine to associate with BMH
  kubectl -n "${namespace}" wait --timeout=5m --for=condition=AssociateBMH "m3m/${metal3machine}"

  # Set correct node name and apply
  # Find UID of BMH by checking the annotation of the m3m that does not yet have a providerID
  # bmh_namespace_name="$(kubectl -n "${namespace}" get m3m -o json | jq -r '.items[] | select(.spec | has("providerID") | not) | .metadata.annotations."metal3.io/BareMetalHost"')"
  # bmh_name="${bmh_namespace_name#*/}"
  # bmh_uid="$(kubectl -n "${namespace}" get bmh "${bmh_name}" -o jsonpath="{.metadata.uid}")"
  # Simplified when working with single node clusters in separate namespaces
  bmh_uid="$(kubectl -n "${namespace}" get bmh -o jsonpath="{.items[0].metadata.uid}")"
  sed -e "s/fake-node/${machine}/g" -e "s/fake-uuid/${bmh_uid}/g" fake-node.yaml | \
    kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml label node "${machine}" node-role.kubernetes.io/control-plane=""

  # Add static pods to make kubeadm control plane manager happy
  sed "s/node-name/${machine}/g" kube-apiserver-pod.yaml | \
    kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
  sed "s/node-name/${machine}/g" kube-controller-manager-pod.yaml | \
    kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
  sed "s/node-name/${machine}/g" kube-scheduler-pod.yaml | \
    kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
  # Set status on the pods (it is not added when using create/apply).
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml -n kube-system patch pod "kube-apiserver-${machine}" \
    --subresource=status --patch-file=kube-apiserver-pod-status.yaml
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml -n kube-system patch pod "kube-controller-manager-${machine}" \
    --subresource=status --patch-file=kube-controller-manager-pod-status.yaml
  kubectl --kubeconfig=/tmp/kubeconfig-test.yaml -n kube-system patch pod "kube-scheduler-${machine}" \
    --subresource=status --patch-file=kube-scheduler-pod-status.yaml

  # TODO: This is triggering rollouts of some KCPs! Why?
  # Add certificate expiry annotations to make kubeadm control plane manager happy
  # kubectl -n "${namespace}" annotate machine "${machine}" "${CERT_EXPIRY_ANNOTATION}=${EXPIRY}"
  # kubectl -n "${namespace}" annotate kubeadmconfig --all "${CERT_EXPIRY_ANNOTATION}=${EXPIRY}"
}

NUM="${1:-10}"
# Add more clusters in steps of step.
STEP="10"

# Certificate expiry for workload API server
# CERT_EXPIRY_ANNOTATION="machine.cluster.x-k8s.io/certificates-expiry"
# EXPIRY_TEXT="$(kubectl -n metal3 get secret apiserver -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -enddate -noout | cut -d= -f 2)"
# EXPIRY="$(date --date="${EXPIRY_TEXT}" --iso-8601=seconds)"

for (( cluster = 1; cluster <= NUM; ++cluster )); do
  create_cluster "test-${cluster}" &
  if (( cluster % STEP == 0 )); then
    echo "Waiting for ${STEP} clusters to be created in the background."
    wait
  fi
done

wait
echo "Created ${NUM} clusters"
