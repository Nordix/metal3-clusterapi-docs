#!/usr/bin/env bash

set -eu

CLUSTER_TEMPLATE=/tmp/cluster-template.yaml
export CLUSTER_APIENDPOINT_PORT="6443"
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
  kubectl -n "${namespace}" create secret tls "${cluster}-etcd" --cert /tmp/pki/etcd/ca.crt --key /tmp/pki/etcd/ca.key
  kubectl -n "${namespace}" create secret tls "${cluster}-ca" --cert /tmp/pki/ca.crt --key /tmp/pki/ca.key
  # For external ETCD
  # kubectl -n "${namespace}" create secret tls "${cluster}-apiserver-etcd-client" --cert /tmp/pki/apiserver-etcd-client.crt --key /tmp/pki/apiserver-etcd-client.key

  export CLUSTER_APIENDPOINT_HOST="test-kube-apiserver.${namespace}.svc.cluster.local"
  # For internal ETCD
  # export CTLPLANE_KUBEADM_EXTRA_CONFIG="
  #   clusterConfiguration:
  #     controlPlaneEndpoint: test-kube-apiserver.${namespace}.svc.cluster.local:6443
  #     apiServer:
  #       certSANs:
  #       - localhost
  #       - 127.0.0.1
  #       - 0.0.0.0
  #       - test-kube-apiserver.${namespace}.svc.cluster.local
  #     etcd:
  #       local:
  #         serverCertSANs:
  #           - etcd-server.${namespace}.cluster.svc.local
  #         peerCertSANs:
  #           - etcd-0.etcd.${namespace}.cluster.svc.local"
  export CTLPLANE_KUBEADM_EXTRA_CONFIG="
    clusterConfiguration:
      controlPlaneEndpoint: test-kube-apiserver.${namespace}.svc.cluster.local:6443
      apiServer:
        certSANs:
        - localhost
        - 127.0.0.1
        - 0.0.0.0
        - test-kube-apiserver.${namespace}.svc.cluster.local
      etcd:
        external:
          endpoints:
            - https://etcd-server:2379
          caFile: /etc/kubernetes/pki/etcd/ca.crt
          certFile: /etc/kubernetes/pki/apiserver-etcd-client.crt
          keyFile: /etc/kubernetes/pki/apiserver-etcd-client.key"

  # Create cluster!
  clusterctl generate cluster "${cluster}" \
    --from "${CLUSTER_TEMPLATE}" \
    --target-namespace "${namespace}" | kubectl apply -f -

  ## Generate certificates

  # Kubeadm is configured to use /tmp/${cluster}/pki as certificate directory
  rm --recursive --force "/tmp/${cluster}/pki"
  mkdir -p "/tmp/${cluster}/pki/etcd"

  # Generate etcd client certificate
  openssl req -newkey rsa:2048 -nodes -subj "/CN=${cluster}" \
   -keyout "/tmp/${cluster}/pki/apiserver-etcd-client.key" -out "/tmp/${cluster}/pki/apiserver-etcd-client.csr"
  openssl x509 -req -in "/tmp/${cluster}/pki/apiserver-etcd-client.csr" \
    -CA /tmp/pki/etcd/ca.crt -CAkey /tmp/pki/etcd/ca.key -CAcreateserial \
    -out "/tmp/${cluster}/pki/apiserver-etcd-client.crt" -days 365

  # Get the etcd ca certificate and key.
  # This is used by kubeadm to generate etcd peer, server and client certificates
  # kubectl -n "${namespace}" get secrets "${cluster}-etcd" -o jsonpath="{.data.tls\.crt}" | base64 -d > "/tmp/${cluster}/pki/etcd/ca.crt"
  # kubectl -n "${namespace}" get secrets "${cluster}-etcd" -o jsonpath="{.data.tls\.key}" | base64 -d > "/tmp/${cluster}/pki/etcd/ca.key"
  # Get the k8s ca certificate and key.
  # This is used by kubeadm to generate the api server certificates
  kubectl -n "${namespace}" get secrets "${cluster}-ca" -o jsonpath="{.data.tls\.crt}" | base64 -d > "/tmp/${cluster}/pki/ca.crt"
  kubectl -n "${namespace}" get secrets "${cluster}-ca" -o jsonpath="{.data.tls\.key}" | base64 -d > "/tmp/${cluster}/pki/ca.key"

  # Generate certificates (this would normally happen on the node)
  sed -e "s/NAMESPACE/${namespace}/g" -e "s/CLUSTER/${cluster}/g" manifests/v2/kubeadm-config.yaml > "/tmp/kubeadm-config-${cluster}.yaml"
  # kubeadm init phase certs etcd-peer --config "/tmp/kubeadm-config-${cluster}.yaml"
  # kubeadm init phase certs etcd-server --config "/tmp/kubeadm-config-${cluster}.yaml"
  # Not needed since we use external ETCD
  # kubeadm init phase certs apiserver-etcd-client --config "/tmp/kubeadm-config-${cluster}.yaml"
  kubeadm init phase certs apiserver --config "/tmp/kubeadm-config-${cluster}.yaml"

  # Create secrets
  # kubectl -n "${namespace}" create secret tls etcd-peer --cert "/tmp/${cluster}/pki/etcd/peer.crt" --key "/tmp/${cluster}/pki/etcd/peer.key"
  # kubectl -n "${namespace}" create secret tls etcd-server --cert "/tmp/${cluster}/pki/etcd/server.crt" --key "/tmp/${cluster}/pki/etcd/server.key"
  kubectl -n "${namespace}" create secret tls "${cluster}-apiserver-etcd-client" --cert "/tmp/${cluster}/pki/apiserver-etcd-client.crt" --key "/tmp/${cluster}/pki/apiserver-etcd-client.key"
  kubectl -n "${namespace}" create secret tls apiserver --cert "/tmp/${cluster}/pki/apiserver.crt" --key "/tmp/${cluster}/pki/apiserver.key"

  ## Create etcd tenant
  # Create user
  kubectl -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    user add "${cluster}" --new-user-password="${cluster}"
  # Create role
  kubectl -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    role add "${cluster}"
  # Add read/write permissions for prefix to the role
  kubectl -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    role grant-permission "${cluster}" --prefix=true readwrite "/${cluster}/"
  # Give the user permissions from the role
  kubectl -n etcd-system exec etcd-0 -- etcdctl --user root:rootpw \
    --key=/etc/kubernetes/pki/etcd/tls.key --cert=/etc/kubernetes/pki/etcd/tls.crt --cacert /etc/kubernetes/pki/ca/tls.crt \
    user grant-role "${cluster}" "${cluster}"

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

  # Deploy API server
  sed "s/CLUSTER/${cluster}/g" manifests/v2/kube-apiserver-deployment.yaml | kubectl -n "${namespace}" apply -f -
  kubectl -n "${namespace}" wait --for=condition=Available deploy/test-kube-apiserver

  # Get kubeconfig
  clusterctl -n "${namespace}" get kubeconfig "${cluster}" > "/tmp/kubeconfig-${cluster}.yaml"
  # Edit kubeconfig to point to 127.0.0.1:6443 and set up port forward to the pod
  # Pick a unique port for port-forwarding: 10000 + cluster number
  cluster_number="${cluster#test-}"
  port="1$(printf "%0*d" 4 "${cluster_number}")"
  sed -i -e "s/test-kube-apiserver.${namespace}.svc.cluster.local/127.0.0.1/" \
    -e "s/:6443/:${port}/" "/tmp/kubeconfig-${cluster}.yaml"

  # It takes some time for etcd and the API server to properly initialize.
  retries=15
  for (( retry = 1; retry <= retries; ++retry )); do
    kubectl -n "${namespace}" port-forward svc/test-kube-apiserver "${port}":6443 &
    port_forward_pid=$!
    # Check that the port forward worked
    if ps -p "${port_forward_pid}" -o pid=; then
      # shellcheck disable=SC2064 # We want to expand the variable right now when it is defined.
      trap "kill ${port_forward_pid}" EXIT
      break
    fi
    sleep 2
  done
  # Now that we have port forwarding, let's check also that it initialized
  for (( retry = 1; retry <= retries; ++retry )); do
    # Check that the priority classe exists
    if kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" get priorityclasses.scheduling.k8s.io system-node-critical &> /dev/null; then
      break
    fi
    sleep 2
  done

  # Set correct node name and apply
  # Find UID of BMH by checking the annotation of the m3m that does not yet have a providerID
  # bmh_namespace_name="$(kubectl -n "${namespace}" get m3m -o json | jq -r '.items[] | select(.spec | has("providerID") | not) | .metadata.annotations."metal3.io/BareMetalHost"')"
  # bmh_name="${bmh_namespace_name#*/}"
  # bmh_uid="$(kubectl -n "${namespace}" get bmh "${bmh_name}" -o jsonpath="{.metadata.uid}")"
  # Simplified when working with single node clusters in separate namespaces
  bmh_uid="$(kubectl -n "${namespace}" get bmh -o jsonpath="{.items[0].metadata.uid}")"
  sed -e "s/fake-node/${machine}/g" -e "s/fake-uuid/${bmh_uid}/g" fake-node.yaml | \
    kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" create -f -
  kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" label node "${machine}" node-role.kubernetes.io/control-plane=""
  # Upload kubeadm config to configmap. This will mark the KCP as initialized.
  kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" -n kube-system create cm kubeadm-config \
    --from-file=ClusterConfiguration="/tmp/kubeadm-config-${cluster}.yaml"

  # Add static pods to make kubeadm control plane manager happy
  sed "s/node-name/${machine}/g" kube-apiserver-pod.yaml | \
    kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" create -f -
  sed "s/node-name/${machine}/g" kube-controller-manager-pod.yaml | \
    kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" create -f -
  sed "s/node-name/${machine}/g" kube-scheduler-pod.yaml | \
    kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" create -f -
  # Set status on the pods (it is not added when using create/apply).
  kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" -n kube-system patch pod "kube-apiserver-${machine}" \
    --subresource=status --patch-file=kube-apiserver-pod-status.yaml
  kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" -n kube-system patch pod "kube-controller-manager-${machine}" \
    --subresource=status --patch-file=kube-controller-manager-pod-status.yaml
  kubectl --kubeconfig="/tmp/kubeconfig-${cluster}.yaml" -n kube-system patch pod "kube-scheduler-${machine}" \
    --subresource=status --patch-file=kube-scheduler-pod-status.yaml

  # Add certificate expiry annotations to make kubeadm control plane manager happy
  kubectl -n "${namespace}" annotate machine "${machine}" "${CERT_EXPIRY_ANNOTATION}=${EXPIRY}"
  kubectl -n "${namespace}" annotate kubeadmconfig --all "${CERT_EXPIRY_ANNOTATION}=${EXPIRY}"

  # rm "/tmp/kubeconfig-${cluster}.yaml"
}

NUM="${1:-10}"
# Add more clusters in steps of step.
STEP="10"

# Certificate expiry for workload API server
CERT_EXPIRY_ANNOTATION="machine.cluster.x-k8s.io/certificates-expiry"
EXPIRY_TEXT="$(kubectl -n metal3 get secret apiserver -o jsonpath="{.data.tls\.crt}" | base64 -d | openssl x509 -enddate -noout | cut -d= -f 2)"
EXPIRY="$(date --date="${EXPIRY_TEXT}" --iso-8601=seconds)"

for (( cluster = 1; cluster <= NUM; ++cluster )); do
  create_cluster "test-${cluster}" &
  if (( cluster % STEP == 0 )); then
    echo "Waiting for ${STEP} clusters to be created in the background."
    wait
  fi
done

wait
echo "Created ${NUM} clusters"
