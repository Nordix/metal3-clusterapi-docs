WORKLOAD_CLUSTER="--kubeconfig=capi-kubeconfig"
KUBE_CONTROLLER_MANAGER=$(docker ps --format '{{.Names}}' | grep controlplane)
base64_encoded_ca_new="$(base64 cert/clusterCA/ca-new.crt |  awk 'BEGIN{ORS="";} {print}')" 
for namespace in $(kubectl ${WORKLOAD_CLUSTER} get ns --no-headers | awk '{print $1}')
do
 for token in $(kubectl ${WORKLOAD_CLUSTER} get secrets --namespace "$namespace" --field-selector type=kubernetes.io/service-account-token -o name)
 do
   kubectl ${WORKLOAD_CLUSTER} get $token --namespace "$namespace" -o yaml | sed "s/\(ca.crt:\).*/\1 ${base64_encoded_ca_new}/" | kubectl ${WORKLOAD_CLUSTER} apply -f -
 done
done

restart_pod=$(kubectl ${WORKLOAD_CLUSTER} -n kube-system get pod --no-headers | awk '{print $1}')
for POD in "${restart_pod}"
do
  kubectl ${WORKLOAD_CLUSTER} -n kube-system delete pod ${POD}
  sleep 10 
done

# 11.2
WORKLOAD_CLUSTER="--kubeconfig=capi-kubeconfig"
KUBE_CONTROLLER_MANAGER=$(docker ps --format '{{.Names}}' | grep controlplane)
CA_NEW_ENCODED=$(base64 "./cert/clusterCA/ca-new.crt" | awk 'BEGIN{ORS="";} {print}')
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" new-credentials/admin.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" new-credentials/kubelet.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" new-credentials/controller-manager.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" new-credentials/scheduler.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" new-credentials/bootstrap-kubelet.conf


sed -i "s/\(client-certificate:\).*/\1 \/var\/lib\/kubelet\/pki\/kubelet-client-current.crt/" new-credentials/kubelet.conf
sed -i "s/\(client-key:\).*/\1 \/var\/lib\/kubelet\/pki\/kubelet-client-current.key/" new-credentials/kubelet.conf
sed -i "s/\(clientCAFile: \/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/" kubelet-config-new.yaml
docker cp kubelet-config-new.yaml ${KUBE_CONTROLLER_MANAGER}:/var/lib/kubelet/config.yaml
# Restart kubelet
docker exec ${KUBE_CONTROLLER_MANAGER} systemctl restart kubelet

docker cp new-credentials/. ${KUBE_CONTROLLER_MANAGER}:/etc/kubernetes/
docker cp ${KUBE_CONTROLLER_MANAGER}:/etc/kubernetes/admin.conf capi-kubeconfig
# Replace CA for controler-manager
sed -i "s/\(--root-ca-file=\/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/"  kube-controller-manager.yaml
# Replace CA for apiserver
sed -i "s/\(--client-ca-file=\/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/" new-manifests/kube-apiserver.yaml
yq e '.spec.containers[0].command += "--kubelet-certificate-authority=/etc/kubernetes/pki/ca-new.crt"' -i new-manifests/kube-apiserver.yaml

# Replace CA kubelet in worker node
WORKER_NODE=$(docker ps --format '{{.Names}}' | grep worker)
# Edit conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" worker-new/kubelet.conf
# Bootstrap kubelet
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" worker-new/bootstrap-kubelet.conf
# copy conf
docker cp worker-new/kubelet.conf ${WORKER_NODE}:/etc/kubernetes/
docker cp worker-new/bootstrap-kubelet.conf ${WORKER_NODE}:/etc/kubernetes/
sed -i "s/\(clientCAFile: \/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/" worker-new/config.yaml
# copy config file
docker cp worker-new/config.yaml ${WORKER_NODE}:/var/lib/kubelet/config.yaml
# Restart kubelet on worker node
docker exec ${WORKER_NODE} systemctl restart kubelet
