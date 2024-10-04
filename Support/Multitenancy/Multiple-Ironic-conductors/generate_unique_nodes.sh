#!/bin/bash
set -e
rm -rf macaddrs uuids nodes.json node.json

function macgen {
    hexdump -n 6 -ve '1/1 "%.2x "' /dev/random | awk -v a="2,6,a,e" -v r="$RANDOM" 'BEGIN{srand(r);}NR==1{split(a,b,",");r=int(rand()*4+1);printf "%s%s:%s:%s:%s:%s:%s\n",substr($1,0,1),b[r],$2,$3,$4,$5,$6}'
}

function generate_unique {
    func=$1
    store_file=$2
    newgen=$($func)
    if [[ ! -f "$store_file" || $(grep "$newgen" "$store_file") == "" ]]; then
	echo "$newgen" >> "$store_file"
	echo "$newgen"
	return
    fi
    $func
}

echo '[]' > nodes.json

for i in $(seq 1 "${N_NODES:-100}"); do
  uuid=$(generate_unique uuidgen uuids)
  macaddr=$(generate_unique macgen macaddrs)
  name="test${i}" 
  jq --arg node_name "${name}" \
    --arg uuid "${uuid}" \
    --arg macaddr "${macaddr}" \
    '{
      "uuid": $uuid,
      "name": $node_name,
      "power_state": "Off",
      "external_notifier": "True",
      "nics": [
	{"mac": $macaddr, "ip": "192.168.0.100"}
      ]
    }' nodes_template.json > node.json

  jq -s '.[0] + [.[1] ]' nodes.json node.json > tmp.json
  rm -f nodes.json
  mv tmp.json nodes.json
done
