#!/bin/bash
#
export N_NODES=20
export N_FAKE_IPAS=2
export N_IRONICS=2
export N_FKAS=1

# Minikube configuration
export MINIKUBE_CPUS=4
export MINIKUBE_MEMORY=10000

# Note: N_CLUSTERS is the number of clusters to provision,
# while CP_NODE_COUNT and WORKER_NODE_COUNT are the number of
# CP nodes and worker nodes in each of these clusters.
# The user is responsible to make sure that
# N_CLUSTERS*(CP_NODE_COUNT+WORKER_NODE_COUNT) <= N_NODES
export N_CLUSTERS=10
export CP_NODE_COUNT=1
export WORKER_NODE_COUNT=1

# Translating N_IRONICS to IRONIC_ENDPOINTS. Don't change this part
IRONIC_ENDPOINTS="192.168.222.100"
for i in $(seq 2 $N_IRONICS); do
  IRONIC_ENDPOINTS="${IRONIC_ENDPOINTS} 192.168.222.$((100 + i))"
done
export IRONIC_ENDPOINTS
