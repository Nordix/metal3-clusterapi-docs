#!/bin/bash
TARGET_CLUSTER=192.168.111.21
# Source cluster: collect kubeconfig for source and target clusters.
cd ~/metal3-dev-env/
cp ~/.kube/config source.yaml
scp ubuntu@"${TARGET_CLUSTER}":/home/ubuntu/.kube/config target.yaml
# Source cluster: create a text file from lease files
export bmo_pod=$(kubectl  get pods -n metal3 -o name | grep 'metal3-baremetal-operator' | cut -f2 -d'/')
kubectl exec -n metal3 $bmo_pod -c ironic-dnsmasq cat /var/lib/dnsmasq/dnsmasq.leases > /tmp/dnsmasq.leases
# Target cluster: Create config from a lease file content | commands run on the source cluster remotely.
scp /tmp/dnsmasq.leases ubuntu@"${TARGET_CLUSTER}":/tmp/dnsmasq.leases
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl create ns metal3
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl create configmap dnsmasq-leases-configmap --from-file=dnsmasq.leases=/tmp/dnsmasq.leases -n metal3
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl get configmap dnsmasq-leases-configmap -o yaml -n metal3
# Source cluster: Start pivoting
cd ~/go/src/sigs.k8s.io/cluster-api/cmd/clusterctl/
alias pivot='./clusterctl alpha phases pivot -p ~/go/src/sigs.k8s.io/cluster-api/provider-components-target.yaml  -s ~/metal3-dev-env/source.yaml -t ~/metal3-dev-env/target.yaml -v 5'
pivot
# Target Cluster: verify that:
# 1. All controllers are up running (2) bmh state is maintained (3) dhcp leases are loaded correctly.
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl get pods -n metal3
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl get bmh -n metal3 -o yaml
ssh ubuntu@"${TARGET_CLUSTER}" -- export bmo_pod=$(kubectl  get pods -n metal3 -o name | grep 'metal3-baremetal-operator' | cut -f2 -d'/')
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl exec -n metal3 $bmo_pod -c ironic-dnsmasq cat /var/lib/dnsmasq/dnsmasq.leases
# Target cluster: Provision a worker | replace with the correct worker yaml file.
 minikube ssh sudo ip addr del 172.22.0.2/24 dev eth2
cd ~/metal3-dev-env/
scp worker_New.yaml  ubuntu@"${TARGET_CLUSTER}":/tmp
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl apply -f /tmp/worker_New.yaml -n metal3
# Target cluster: Verify that worker is provisioned.
ssh ubuntu@"${TARGET_CLUSTER}" -- kubectl get bmh -n metal3

