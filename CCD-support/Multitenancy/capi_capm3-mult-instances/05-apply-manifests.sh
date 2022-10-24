set -e

wget -q https://github.com/cert-manager/cert-manager/releases/download/v1.5.3/cert-manager.yaml -O  cert-manager.yaml
kubectl apply -f cert-manager.yaml
sleep 30
# Apply ironic/bmo
kubectl apply -f test1-manifests/ironic.yaml -n baremetal-operator-system-test1
kubectl apply -f test2-manifests/ironic.yaml -n baremetal-operator-system-test2
kubectl apply -f test1-manifests/bmo.yaml -n baremetal-operator-system-test1
kubectl apply -f test2-manifests/bmo.yaml -n baremetal-operator-system-test2
# Create namespaces
kubectl create ns test1
kubectl create ns test2
# Apply RBAC roles
kubectl apply -f test1-manifests/role.yaml -n test1
kubectl apply -f test1-manifests/role-binding.yaml -n test1
kubectl apply -f test2-manifests/role.yaml -n test2
kubectl apply -f test2-manifests/role-binding.yaml -n test2
# Apply bmhs
sleep 60
kubectl apply -f test1-manifests/bmh.yaml -n test1
kubectl apply -f test2-manifests/bmh.yaml -n test2

# Get clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.5/clusterctl-linux-amd64 -o clusterctl
chmod +x ./clusterctl
sudo mv ./clusterctl /usr/local/bin/clusterctl

# Download node images
sudo ./dowanload-node-image.sh
kubectl apply -f test1-manifests/capm3.yaml
kubectl apply -f test1-manifests/capi.yaml
kubectl apply -f test1-manifests/kubeadm.yaml
kubectl apply -f test1-manifests/kubeadm-bootstrap.yaml

kubectl apply -f test2-manifests/capi.yaml
kubectl apply -f test2-manifests/kubeadm.yaml
kubectl apply -f test2-manifests/kubeadm-bootstrap.yaml
kubectl apply -f test2-manifests/capm3.yaml
sleep 91
kubectl apply -f test1-manifests/cluster-template.yaml
kubectl apply -f test1-manifests/controlplane-template.yaml
kubectl apply -f test2-manifests/cluster-template.yaml
kubectl apply -f test2-manifests/controlplane-template.yaml


