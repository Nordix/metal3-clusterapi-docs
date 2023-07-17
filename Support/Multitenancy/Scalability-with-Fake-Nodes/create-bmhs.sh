#!/bin/env bash

# Function to generate a random MAC address
generate_random_mac() {
  local mac
  mac=$(hexdump -n 6 -e '6/1 "%02X" "\n"' /dev/random | sed 's/\(..\)/\1:/g; s/.$//')
  # Set the locally administered address bit (2nd least significant bit of the 1st byte) to 1
  local first_byte=$(echo "${mac}" | cut -d: -f1)
  first_byte=$(printf "%02X" $((0x${first_byte} | 0x02)))
  mac=$(echo "${mac}" | sed "s/^.*:/${first_byte}:/")
  echo "${mac}"
}

# Read nodes.json into an array
mapfile -t nodes < <(jq -r '.[] | @json' nodes.json)

# Loop through the nodes and create the manifest files
for node in "${nodes[@]}"; do
  uuid=$(echo "${node}" | jq -r '.uuid')
  name=$(echo "${node}" | jq -r '.name')

  # Calculate the port based on the node name and the N_FAKE_IPAS environment variable
  port=$((8001 + ((${name//[^0-9]/} - 1) % ${N_FAKE_IPAS:-10})))

  # Generate a random MAC address
  random_mac=$(generate_random_mac)

  # Generate the manifest content
  manifest="---
apiVersion: v1
kind: Secret
metadata:
  name: ${name}-bmc-secret
  labels:
      environment.metal3.io: baremetal
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: ${name}
spec:
  online: true
  bmc:
    address: redfish+http://192.168.222.1:${port}/redfish/v1/Systems/${uuid}
    credentialsName: ${name}-bmc-secret
  bootMACAddress: ${random_mac}
  bootMode: legacy
"

  # Write the manifest to a file
  echo "$manifest" >"bmc-${name}.yaml"
  echo "Created manifests for node ${name}"
done
