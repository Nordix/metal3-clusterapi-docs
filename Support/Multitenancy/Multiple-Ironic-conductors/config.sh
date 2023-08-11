#!/bin/bash
#
export N_NODES=1000
export N_SUSHY=120
export N_FAKE_IPA=12
export N_IRONICS=15
export N_APISERVER_PODS=15
# export N_NODES=50
# export N_SUSHY=2
# export N_FAKE_IPA=2
# export N_IRONICS=3

# Translating N_IRONICS to IRONIC_ENDPOINTS. Don't change this part
IRONIC_ENDPOINTS="172.22.0.2"
for i in $(seq 2 $N_IRONICS); do
    IRONIC_ENDPOINTS="${IRONIC_ENDPOINTS} 172.22.0.$(( i + 1 ))"
done
export IRONIC_ENDPOINTS

