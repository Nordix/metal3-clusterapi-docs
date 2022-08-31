set -e
wget https://github.com/cert-manager/cert-manager/releases/download/v1.5.3/cert-manager.yaml
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
sleep 30
kubectl apply -f test1-manifests/bmh.yaml -n test1
kubectl apply -f test2-manifests/bmh.yaml -n test2

# Get clusterctl
curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.5/clusterctl-linux-amd64 -o clusterctl
chmod +x ./clusterctl
sudo mv ./clusterctl /usr/local/bin/clusterctl

# Init the cluster
clusterctl init --core cluster-api:v1.1.5 --bootstrap kubeadm:v1.1.5 --control-plane kubeadm:v1.1.5 --infrastructure=metal3:v1.1.2  -v5
# Apply clusters template
sleep 30
kubectl apply -f test1-manifests/cluster-template.yaml -n test1
kubectl apply -f test2-manifests/cluster-template.yaml -n test2
kubectl apply -f test1-manifests/controlplane-template.yaml -n test1
kubectl apply -f test2-manifests/controlplane-template.yaml -n test2

