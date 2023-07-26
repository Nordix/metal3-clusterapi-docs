#!/bin/bash

ironic_client=${1:-baremetal}
node_names=$("$ironic_client" node list -f json | jq -c -r '.[].Name')

"${ironic_client}" node delete "$node_names"
rm -f nodes.json
