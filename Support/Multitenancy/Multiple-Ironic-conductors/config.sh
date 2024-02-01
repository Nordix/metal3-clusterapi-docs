#!/bin/bash
#
export N_NODES=1000
export N_SUSHY=60
export N_FAKE_IPA=40
export N_IRONICS=50
export N_APISERVER_PODS=5
# export N_NODES=50
# export N_SUSHY=2
# export N_FAKE_IPA=2
# export N_IRONICS=3

# Translating N_IRONICS to IRONIC_ENDPOINTS. Don't change this part
IRONIC_ENDPOINTS="192.168.222.100"
for i in $(seq 2 $N_IRONICS); do
    IRONIC_ENDPOINTS="${IRONIC_ENDPOINTS} 192.168.222.$(( 100+i ))"
done
export IRONIC_ENDPOINTS
