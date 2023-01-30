#!/usr/bin/env bash

set -eu

echo "Fake controller running!"

while :
do
  sleep 5;
  # Find provisioning machines that needs fake nodes
  bmh_namespace_names="$(kubectl -n metal3 get m3m -o json | jq -r '.items[] | select(.spec | has("providerID") | not) | .metadata.annotations."metal3.io/BareMetalHost"')"
  for bmh_namespace_name in ${bmh_namespace_names}; do
    bmh_name="${bmh_namespace_name#*/}"
    bmh_uid="$(kubectl -n metal3 get bmh "${bmh_name}" -o jsonpath="{.metadata.uid}")"
    m3m_name="$(kubectl -n metal3 get bmh "${bmh_name}" -o jsonpath="{.spec.consumerRef.name}")"
    machine_name="$(kubectl -n metal3 get m3m "${m3m_name}" -o jsonpath="{.metadata.ownerReferences[0].name}")"
    echo "Metal3Machine without provider ID: ${m3m_name}. BMH: ${bmh_name}. Machine: ${machine_name}"

    # Check if node already exists.
    if kubectl --kubeconfig=/tmp/kubeconfig-test.yaml get nodes | grep "${machine_name}"; then
      echo "Node already exists. Continuing..."
      continue
    fi

    # Generate fake node.
    echo "Generating fake Node: ${machine_name} with BMH UID: ${bmh_uid}..."
    sed -e "s/fake-node/${machine_name}/g" -e "s/fake-uuid/${bmh_uid}/g" fake-node.yaml | \
      kubectl --kubeconfig=/tmp/kubeconfig-test.yaml create -f -
    echo "Done"
  done
done
