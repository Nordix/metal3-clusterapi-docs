#!/usr/bin/env bash
set -xe
# Backup data
if [ -z "${1:-}" ] 
then
    echo "Usage : run.sh <backup K8s directory>"
    echo ""
    echo "       backup K8s directory: Create a backup for /etc/kubernetes from the controlplane node : \"true\" or \"false\""
    exit 1
fi

KUBE_CONTROLLER_MANAGER=$(docker ps --format '{{.Names}}' | grep controlplane)
mkdir backup -p
mkdir pki-backup -p
mkdir manifests -p
mkdir credentials -p
mkdir new-credentials -p
mkdir new-manifests -p
if [[ $1 == "true" ]] 
then
  docker cp "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/. backup/
  docker cp "${KUBE_CONTROLLER_MANAGER}":/var/lib/kubelet/config.yaml ./kubelet-config-backup.yaml
  cp backup/pki/* pki-backup/ -r
  cp backup/manifests/* manifests/ -r
  cp backup/*.conf credentials/  -r
  cp manifests/kube-controller-manager.yaml .
  cp kubelet-config-backup.yaml kubelet-config-new.yaml
  cp ../capi-kubeconfig .
fi
# Generate Certs
WORKLOAD_CLUSTER="--kubeconfig=capi-kubeconfig"
mkdir -p cert
pushd .
cd cert/
mkdir clusterCA -p 
openssl req -x509 -subj "/CN=Kubernetes API" -new -newkey rsa:2048 -nodes -keyout clusterCA/ca-new.key -sha256 -days 3650 -out clusterCA/ca-new.crt

mkdir etcdCA -p
openssl req -x509 -subj "/CN=ETCD CA" -new -newkey rsa:2048 -nodes -keyout etcdCA/etcd.key -sha256 -days 3650 -out etcdCA/etcd.crt

mkdir frontendProxyCA -p
openssl req -x509 -subj "/CN=Front-End Proxy" -new -newkey rsa:2048 -nodes -keyout frontendProxyCA/front-proxy-ca.key -sha256 -days 3650 -out frontendProxyCA/front-proxy-ca.crt

CA_FILE="clusterCA/ca-new.crt"
CA_KEY="clusterCA/ca-new.key"

popd

# Backup pki folder
echo -n > cert/clusterCA/ca-bundle.crt
cat cert/clusterCA/ca-new.crt >> cert/clusterCA/ca-bundle.crt
cat pki-backup/ca.crt >> cert/clusterCA/ca-bundle.crt

# Copy ca-bundle.crt, ca.crt, ca.key, front-proxy-ca.crt, and front-proxy-ca.key to the cluster
docker cp cert/clusterCA/. "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/pki/
# the new CA (and probably bundle too) needs to be added to the nodes trust chain
docker exec "${KUBE_CONTROLLER_MANAGER}" mkdir -p /etc/pki/trust/anchors/
# c_rehash
# update-ca-certificates
docker cp cert/clusterCA/ca-new.crt "${KUBE_CONTROLLER_MANAGER}":/etc/pki/trust/anchors/ca-new.crt
docker cp cert/clusterCA/ca-bundle.crt "${KUBE_CONTROLLER_MANAGER}":/etc/pki/trust/anchors/ca-bundle.crt
docker cp cert/clusterCA/ca-bundle.crt "${KUBE_CONTROLLER_MANAGER}":/usr/local/share/ca-certificates/
docker cp cert/clusterCA/ca-new.crt "${KUBE_CONTROLLER_MANAGER}":/usr/local/share/ca-certificates/
docker exec "${KUBE_CONTROLLER_MANAGER}" c_rehash
docker exec "${KUBE_CONTROLLER_MANAGER}" update-ca-certificates

# Change parameter of kube-controller-manager
sed -i "s/\(--root-ca-file=\/etc\/kubernetes\/pki\/\).*/\1ca-bundle.crt/"  kube-controller-manager.yaml
sed -i "s/\(--client-ca-file=\/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/"  kube-controller-manager.yaml
sed -i "s/\(--cluster-signing-cert-file=\/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/"  kube-controller-manager.yaml
sed -i "s/\(--cluster-signing-key-file=\/etc\/kubernetes\/pki\/\).*/\1ca-new.key/"  kube-controller-manager.yaml
docker cp kube-controller-manager.yaml "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/manifests/
sleep 9
kubectl ${WORKLOAD_CLUSTER} -n kube-system get pod

# Update all service account tokens to include both old and new CA certificates
base64_encoded_ca="$(base64 cert/clusterCA/ca-bundle.crt |  awk 'BEGIN{ORS="";} {print}')" # awk part is to trim down all new line char ---> avoid problem with s commadn in sed

for namespace in $(kubectl ${WORKLOAD_CLUSTER} get ns --no-headers | awk '{print $1}')
do
 # echo ${namespace}
 for token in $(kubectl ${WORKLOAD_CLUSTER} get secrets --namespace "$namespace" --field-selector type=kubernetes.io/service-account-token -o name)
 do
   # echo $token
   # kubectl ${WORKLOAD_CLUSTER} get $token --namespace "$namespace" -o yaml > tmp
   kubectl "${WORKLOAD_CLUSTER}" get "${token}" --namespace "${namespace}" -o yaml | \
     sed "s/\(ca.crt:\).*/\1 ${base64_encoded_ca}/" | \
     sed "/resourceVersion/d" | \
     kubectl "${WORKLOAD_CLUSTER}" apply -f -
 done
done

# Restart all pods by deleting them
sleep 20
restart_pod=$(kubectl ${WORKLOAD_CLUSTER} -n kube-system get pod --no-headers | awk '{print $1}')
for POD in ${restart_pod}
do
  kubectl "${WORKLOAD_CLUSTER}" -n kube-system delete pod "${POD}"
done



cp manifests/kube-apiserver.yaml new-manifests/
sed -i "s/\(--client-ca-file=\/etc\/kubernetes\/pki\/\).*/\1ca-bundle.crt/" new-manifests/kube-apiserver.yaml
# yq e '.spec.containers[0].command += "--kubelet-certificate-authority=/etc/kubernetes/pki/ca-bundle.crt"' -i new-manifests/kube-apiserver.yaml
docker cp new-manifests/kube-apiserver.yaml "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/manifests/

# Step 6: ignore
# Step 7:
 #  Generate certs for user

# Generate client key
mkdir cert/client/ -p
DEFAULT_ADMIN_KEY="cert/client/default-admin.key"
DEFAULT_AUTH_KEY="cert/client/default-auth.key"
DEFAULT_AUTH_WORKER_KEY="cert/client/default-auth-worker.key"
DEFAULT_CONTROLLER_KEY="cert/client/default-controller-manager.key"
DEFAULT_SCHEDULER_KEY="cert/client/default-scheduler.key"
CA_FILE="cert/clusterCA/ca-new.crt"
CA_KEY="cert/clusterCA/ca-new.key"

openssl genrsa -out "${DEFAULT_ADMIN_KEY}" 2048
openssl genrsa -out "${DEFAULT_AUTH_KEY}" 2048
openssl genrsa -out "${DEFAULT_AUTH_WORKER_KEY}" 2048
openssl genrsa -out "${DEFAULT_CONTROLLER_KEY}" 2048
openssl genrsa -out "${DEFAULT_SCHEDULER_KEY}" 2048
  # Generate client cert
DEFAULT_ADMIN_CRT="cert/client/default-admin.crt"
openssl req -new -key "${DEFAULT_ADMIN_KEY}" -out /tmp/temp.csr -subj "/CN=kubernetes-admin/O=system:masters"
openssl x509 -req -in /tmp/temp.csr -CA "${CA_FILE}" -CAkey "${CA_KEY}" -CAcreateserial -out "${DEFAULT_ADMIN_CRT}" -days 825 -sha256 

DEFAULT_AUTH_CRT="cert/client/default-auth.crt"
openssl req -new -key "${DEFAULT_AUTH_KEY}" -out /tmp/temp.csr -subj "/CN=system:node:${KUBE_CONTROLLER_MANAGER}/O=system:nodes"
openssl x509 -req -in /tmp/temp.csr -CA "${CA_FILE}" -CAkey "${CA_KEY}" -CAcreateserial -out "${DEFAULT_AUTH_CRT}" -days 825 -sha256 

DEFAULT_AUTH_WORKER_CRT="cert/client/default-auth-worker.crt"
WORKER_NODE=$(docker ps --format '{{.Names}}' | grep worker)
openssl req -new -key "${DEFAULT_AUTH_WORKER_KEY}" -out /tmp/temp.csr -subj "/CN=system:node:${WORKER_NODE}/O=system:nodes"
openssl x509 -req -in /tmp/temp.csr -CA "${CA_FILE}" -CAkey "${CA_KEY}" -CAcreateserial -out "${DEFAULT_AUTH_WORKER_CRT}" -days 825 -sha256 

DEFAULT_CONTROLLER_CRT="cert/client/default-controller-manager.crt"
openssl req -new -key "${DEFAULT_CONTROLLER_KEY}" -out /tmp/temp.csr -subj "/CN=system:kube-controller-manager"
openssl x509 -req -in /tmp/temp.csr -CA "${CA_FILE}" -CAkey "${CA_KEY}" -CAcreateserial -out "${DEFAULT_CONTROLLER_CRT}" -days 825 -sha256 

DEFAULT_SCHEDULER_CRT="cert/client/default-scheduler.crt"
openssl req -new -key "${DEFAULT_SCHEDULER_KEY}" -out /tmp/temp.csr -subj "/CN=system:kube-scheduler"
openssl x509 -req -in /tmp/temp.csr -CA "${CA_FILE}" -CAkey "${CA_KEY}" -CAcreateserial -out "${DEFAULT_SCHEDULER_CRT}" -days 825 -sha256 

# Update the certs above to the cluster
if [ ! -f "${KUBECONFIG}" ] 
then
  echo "Cannot find kubectl config file"
  exit 1
fi

# Update user accounts 
mkdir -p new-credentials
cp credentials/* new-credentials/
CA_BUNDLE_ENCODED=$(base64 "./cert/clusterCA/ca-bundle.crt" | awk 'BEGIN{ORS="";} {print}')
#  Update client-certificate-data and client-key-data respectively.
ADMIN_CERT_ENCODED64=$(base64 ${DEFAULT_ADMIN_CRT} | awk 'BEGIN{ORS="";} {print}')
ADMIN_KEY_ENCODED64=$(base64 ${DEFAULT_ADMIN_KEY} | awk 'BEGIN{ORS="";} {print}')
sed -i "s/\(client-certificate-data:\).*/\1 ${ADMIN_CERT_ENCODED64}/" new-credentials/admin.conf
sed -i "s/\(client-key-data:\).*/\1 ${ADMIN_KEY_ENCODED64}/" new-credentials/admin.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_BUNDLE_ENCODED}/" new-credentials/admin.conf

AUTH_CERT_ENCODED64=$(base64 ${DEFAULT_AUTH_CRT} | awk 'BEGIN{ORS="";} {print}')
AUTH_KEY_ENCODED64=$(base64 ${DEFAULT_AUTH_KEY} | awk 'BEGIN{ORS="";} {print}')
sed -i "s/\(client-certificate-data:\).*/\1 ${AUTH_CERT_ENCODED64}/" new-credentials/kubelet.conf
sed -i "s/\(client-key-data:\).*/\1 ${AUTH_KEY_ENCODED64}/" new-credentials/kubelet.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_BUNDLE_ENCODED}/" new-credentials/kubelet.conf

CONTROLLER_CERT_ENCODED64=$(base64 ${DEFAULT_CONTROLLER_CRT} | awk 'BEGIN{ORS="";} {print}')
CONTROLLER_KEY_ENCODED64=$(base64 ${DEFAULT_CONTROLLER_KEY} | awk 'BEGIN{ORS="";} {print}')
sed -i "s/\(client-certificate-data:\).*/\1 ${CONTROLLER_CERT_ENCODED64}/" new-credentials/controller-manager.conf
sed -i "s/\(client-key-data:\).*/\1 ${CONTROLLER_KEY_ENCODED64}/" new-credentials/controller-manager.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_BUNDLE_ENCODED}/" new-credentials/controller-manager.conf

SCHEDULER_CERT_ENCODED64=$(base64 ${DEFAULT_SCHEDULER_CRT} | awk 'BEGIN{ORS="";} {print}')
SCHEDULER_KEY_ENCODED64=$(base64 ${DEFAULT_SCHEDULER_KEY} | awk 'BEGIN{ORS="";} {print}')
sed -i "s/\(client-certificate-data:\).*/\1 ${SCHEDULER_CERT_ENCODED64}/" new-credentials/scheduler.conf
sed -i "s/\(client-key-data:\).*/\1 ${SCHEDULER_KEY_ENCODED64}/" new-credentials/scheduler.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_BUNDLE_ENCODED}/" new-credentials/scheduler.conf

# Update CA in bootstrap-kubelet.conf
# docker cp ${KUBE_CONTROLLER_MANAGER}:/etc/kubernetes/bootstrap-kubelet.conf credentials/
# sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_BUNDLE_ENCODED}/" new-credentials/bootstrap-kubelet.conf
docker cp new-credentials/. "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/
CA_BUNDLE_ENCODED=$(base64 "./cert/clusterCA/ca-bundle.crt" | awk 'BEGIN{ORS="";} {print}')
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_BUNDLE_ENCODED}/" capi-kubeconfig

# Still step 7: update capi-kubeconfig certificate-authority-data section in the kubeconfig files, respectively with Base64-encoded old and new certificate authority data
                
# Step 8:
 # Step 8.1: Restart kube-api server
sleep 20
kubectl "${WORKLOAD_CLUSTER}" -n kube-system delete pod kube-apiserver-"${KUBE_CONTROLLER_MANAGER}" || true
sleep 5
 # Step 8.2: Only update certificate-authority-data as clientCAFile is not used by CCD
# sed -i "s/\(client-certificate:\).*/\1 \/var\/lib\/kubelet\/pki\/kubelet-client-current.crt/" new-credentials/kubelet.conf
# sed -i "s/\(client-key:\).*/\1 \/var\/lib\/kubelet\/pki\/kubelet-client-current.key/" new-credentials/kubelet.conf
sed -i "s/\(clientCAFile: \/etc\/kubernetes\/pki\/\).*/\1ca-bundle.crt/" kubelet-config-new.yaml
cat cert/client/default-auth.crt cert/client/default-auth.key > cert/client/default-auth.pem
docker cp cert/client/default-auth.pem "${KUBE_CONTROLLER_MANAGER}":/var/lib/kubelet/pki/kubelet-client-current.pem
docker cp kubelet-config-new.yaml "${KUBE_CONTROLLER_MANAGER}":/var/lib/kubelet/config.yaml
docker cp new-credentials/kubelet.conf "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/
# Offically restart kubelet
docker exec "${KUBE_CONTROLLER_MANAGER}" systemctl restart kubelet

# step 8.3: 
# apiserver.crt, apiserver-kubelet-client.crt and front-proxy-client.crt
mkdir cert/apiserver -p
mkdir cert/frontendProxyCA/ -p
CA_FILE="cert/clusterCA/ca-new.crt"
CA_KEY="cert/clusterCA/ca-new.key"
APISERVER_KEY="cert/apiserver/apiserver.key"
APISERVER_CRT="cert/apiserver/apiserver.crt"
CN_APISERVER="kube-apiserver"
APISERVER_KUBELET_CLIENT_KEY="backup/pki/apiserver-kubelet-client.key"
APISERVER_KUBELET_CLIENT_CRT="cert/apiserver/apiserver-kubelet-client.crt" # Using old key, otherwise new clusterRole and clusterRolebinging are needed to give permission for NEW USER.
CN_KUBELET_CLIENT="kube-apiserver-kubelet-client"
FRONT_CA_KEY="cert/frontendProxyCA/front-proxy-ca.key"
FRONT_CA_CRT="cert/frontendProxyCA/front-proxy-ca.crt"
FRONT_PROXY_CLIENT_KEY="backup/pki/front-proxy-client.key"
FRONT_PROXY_CLIENT_CRT="cert/frontendProxyCA/front-proxy-client.crt"
CN_FRONT_PROXY_CLIENT="front-proxy-client"

openssl genrsa -out "${APISERVER_KEY}" 2048
# Using old key, otherwise new clusterRole and clusterRolebinging are needed to give permission for NEW USER
# openssl genrsa -out "${APISERVER_KUBELET_CLIENT_KEY}" 2048
# openssl genrsa -out "${FRONT_PROXY_CLIENT_KEY}" 2048

openssl req -new -key "${APISERVER_KEY}" -out /tmp/temp.csr -subj "/CN=${CN_APISERVER}"
openssl x509 -req -in /tmp/temp.csr -CA "${CA_FILE}" -CAkey "${CA_KEY}" -CAcreateserial -out "${APISERVER_CRT}" -days 825 -sha256 -extfile <( printf "subjectAltName=DNS:%s, DNS:kubernetes, DNS:kubernetes.default, DNS:kubernetes.default.svc, DNS:kubernetes.default.svc.cluster.local, IP:10.96.0.1, IP:172.17.0.6, IP:172.17.0.3, IP:172.17.0.4" "${KUBE_CONTROLLER_MANAGER}")

openssl req -new -key "${APISERVER_KUBELET_CLIENT_KEY}" -out /tmp/temp.csr -subj "/O=system:masters/CN=${CN_KUBELET_CLIENT}"
openssl x509 -req -in /tmp/temp.csr -CA "${CA_FILE}" -CAkey "${CA_KEY}" -CAcreateserial -out "${APISERVER_KUBELET_CLIENT_CRT}" -days 825 -sha256 

openssl req -new -key "${FRONT_PROXY_CLIENT_KEY}" -out /tmp/temp.csr -subj "/CN=${CN_FRONT_PROXY_CLIENT}"
openssl x509 -req -in /tmp/temp.csr -CA "${FRONT_CA_CRT}" -CAkey "${FRONT_CA_KEY}" -CAcreateserial -out "${FRONT_PROXY_CLIENT_CRT}" -days 825 -sha256 

# Copy new certs to /etc/kubernetes/pki/
docker cp cert/apiserver/. "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/pki/
docker cp cert/frontendProxyCA/. "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/pki/

# Restart apiserver and scheduler
sleep 20
kubectl "${WORKLOAD_CLUSTER}" -n kube-system delete pod kube-apiserver-"${KUBE_CONTROLLER_MANAGER}" || true
kubectl "${WORKLOAD_CLUSTER}" -n kube-system delete pod kube-scheduler-"${KUBE_CONTROLLER_MANAGER}" || true

# Step 8.4: Annotate any Daemonsets and Deployments to trigger pod replacement in a safer rolling fashion
WORKLOAD_CLUSTER="--kubeconfig=capi-kubeconfig"
for namespace in $(kubectl ${WORKLOAD_CLUSTER} get namespace -o jsonpath='{.items[*].metadata.name}'); 
do
  for name in $(kubectl "${WORKLOAD_CLUSTER}" get deployments -n "${namespace}" -o jsonpath='{.items[*].metadata.name}'); 
  do
    kubectl "${WORKLOAD_CLUSTER}" patch deployment -n "${namespace}" "${name}" -p '{"spec":{"template":{"metadata":{"annotations":{"ca-rotation": "1"}}}}}';
  done
  for name in $(kubectl "${WORKLOAD_CLUSTER}" get daemonset -n "${namespace}" -o jsonpath='{.items[*].metadata.name}'); do
    kubectl "${WORKLOAD_CLUSTER}" patch daemonset -n "${namespace}" "${name}" -p '{"spec":{"template":{"metadata":{"annotations":{"ca-rotation": "1"}}}}}';
  done
done

docker exec "${KUBE_CONTROLLER_MANAGER}" sh -c "rm /etc/kubernetes/manifests/*"
sleep 10
docker cp manifests/. "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/manifests/
docker cp kube-controller-manager.yaml "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/manifests/
docker cp new-manifests/kube-apiserver.yaml "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/manifests/
sleep 20

docker cp cert/clusterCA/. "${WORKER_NODE}":/etc/kubernetes/pki/
docker cp cert/apiserver/. "${WORKER_NODE}":/etc/kubernetes/pki/
docker cp cert/frontendProxyCA/. "${WORKER_NODE}":/etc/kubernetes/pki/
cat cert/client/default-auth-worker.crt cert/client/default-auth-worker.key > cert/client/default-auth-worker.pem
docker cp cert/client/default-auth-worker.pem "${WORKER_NODE}":/var/lib/kubelet/pki/kubelet-client-current.pem
mkdir -p worker-backup/
mkdir -p worker-new/
if [[ $1 == "true" ]] 
then
  docker cp "${WORKER_NODE}":/etc/kubernetes/kubelet.conf worker-backup/
  cp worker-backup/kubelet.conf worker-new/
  docker cp "${WORKER_NODE}":/var/lib/kubelet/config.yaml worker-backup/
  cp worker-backup/config.yaml worker-new/
fi
sed -i "s/\(client-certificate-data:\).*/\1 ${AUTH_CERT_ENCODED64}/" worker-new/kubelet.conf
sed -i "s/\(client-key-data:\).*/\1 ${AUTH_KEY_ENCODED64}/" worker-new/kubelet.conf
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_BUNDLE_ENCODED}/" worker-new/kubelet.conf
docker cp worker-new/kubelet.conf "${WORKER_NODE}":/etc/kubernetes/

sed -i "s/\(clientCAFile: \/etc\/kubernetes\/pki\/\).*/\1ca-bundle.crt/" worker-new/config.yaml
docker cp worker-new/config.yaml "${WORKER_NODE}":/var/lib/kubelet/config.yaml
docker exec "${WORKER_NODE}" systemctl restart kubelet
                                    
# Step 9: Update bootstrap token 
sleep 20 # Wait for kubelet to fully work after restarting
base64_encoded_ca_new="$(base64 cert/clusterCA/ca-new.crt | tr -d '\n')"
kubectl ${WORKLOAD_CLUSTER} get cm/cluster-info --namespace kube-public -o yaml | \
      sed "s/\(certificate-authority-data:\).*/\1 ${base64_encoded_ca_new}/" | \
      sed "/resourceVersion/d" | \
      sed "/uid/d" | \
      sed "/creationTimestamp/d" | \
      kubectl ${WORKLOAD_CLUSTER} apply -f -


base64_encoded_ca_new="$(base64 cert/clusterCA/ca-new.crt |  awk 'BEGIN{ORS="";} {print}')" # awk part is to trim down all new line char ---> avoid problem with s commadn in sed
for namespace in $(kubectl ${WORKLOAD_CLUSTER} get ns --no-headers | awk '{print $1}')
do
 # echo ${namespace}
 for token in $(kubectl "${WORKLOAD_CLUSTER}" get secrets --namespace "$namespace" --field-selector type=kubernetes.io/service-account-token -o name)
 do
   # echo $token
   # kubectl ${WORKLOAD_CLUSTER} get $token --namespace "$namespace" -o yaml > tmp
   kubectl "${WORKLOAD_CLUSTER}" get "$token" --namespace "$namespace" -o yaml | sed "s/\(ca.crt:\).*/\1 ${base64_encoded_ca_new}/" | kubectl "${WORKLOAD_CLUSTER}" apply -f -
 done
done

restart_pod="$(kubectl ${WORKLOAD_CLUSTER} -n kube-system get pod --no-headers | awk '{print $1}')"
for POD in ${restart_pod}
do
  kubectl "${WORKLOAD_CLUSTER}" -n kube-system delete pod "${POD}"
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
# sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" new-credentials/bootstrap-kubelet.conf

sed -i "s/\(clientCAFile: \/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/" kubelet-config-new.yaml
docker cp kubelet-config-new.yaml "${KUBE_CONTROLLER_MANAGER}":/var/lib/kubelet/config.yaml
# Restart kubelet
docker exec "${KUBE_CONTROLLER_MANAGER}" systemctl restart kubelet

docker cp new-credentials/. "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/
docker cp "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/admin.conf capi-kubeconfig
# Replace CA for controler-manager
sed -i "s/\(--root-ca-file=\/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/"  kube-controller-manager.yaml
# Replace CA for apiserver
sed -i "s/\(--client-ca-file=\/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/" new-manifests/kube-apiserver.yaml
# sed -i "s/\(--kubelet-certificate-authority=\/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/" new-manifests/kube-apiserver.yaml
# # Restart static pod
docker exec "${KUBE_CONTROLLER_MANAGER}" sh -c "rm /etc/kubernetes/manifests/*"
sleep 10
docker cp manifests/. "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/manifests/
docker cp kube-controller-manager.yaml "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/manifests/
docker cp new-manifests/kube-apiserver.yaml "${KUBE_CONTROLLER_MANAGER}":/etc/kubernetes/manifests/
sleep 20

# # Replace CA kubelet in worker node
sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" worker-new/kubelet.conf
# Bootstrap kubelet
# sed -i "s/\(certificate-authority-data:\).*/\1 ${CA_NEW_ENCODED}/" worker-new/bootstrap-kubelet.conf
docker cp worker-new/kubelet.conf "${WORKER_NODE}":/etc/kubernetes/
# docker cp worker-new/bootstrap-kubelet.conf ${WORKER_NODE}:/etc/kubernetes/
sed -i "s/\(clientCAFile: \/etc\/kubernetes\/pki\/\).*/\1ca-new.crt/" worker-new/config.yaml
docker cp worker-new/config.yaml "${WORKER_NODE}":/var/lib/kubelet/config.yaml
# # Restart kubelet on worker node
docker exec "${WORKER_NODE}" systemctl restart kubelet

