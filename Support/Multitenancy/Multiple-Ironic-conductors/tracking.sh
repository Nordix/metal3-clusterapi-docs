#!/bin/bash
#
OUTPUT_FILE="/home/cloud-user/metal3-clusterapi-docs/Support/Multitenancy/Multiple-Ironic-conductors/track.csv"
KUBECTL=/usr/local/bin/kubectl
KUBECONFIG_FILE="/home/cloud-user/.kube/config"
if [ ! -f "${OUTPUT_FILE}" ]; then
    echo "Time,Nodes,Provisioned,Error" >  ${OUTPUT_FILE}
fi
echo "$(date +%H:%M:%S),$(${KUBECTL} --kubeconfig ${KUBECONFIG_FILE} get bmh -A --no-headers | wc -l),$(${KUBECTL} --kubeconfig ${KUBECONFIG_FILE} get machines -A | grep -c Running),$(${KUBECTL} --kubeconfig ${KUBECONFIG_FILE} get bmh -A | grep -c error)" >> ${OUTPUT_FILE}

