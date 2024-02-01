#!/bin/bash

cluster_name="${1}"
action="${2}"

# Network interface management
if [ "${action}" == "add" ]; then
    master_machines=$(kinder get nodes --name "${cluster_name}" | grep -iE 'control')
    master_networks=$(docker network list --format '{{.Name}}' | grep -iE "control" | sort)

    for network in ${master_networks}; do
        for machine in ${master_machines}; do
            echo -e "Adding machine ${machine} from ${network}"
            docker network connect "${network}" "${machine}"
        done
    done

    worker_machines=$(kinder get nodes --name "${cluster_name}" | grep 'worker')
    worker_networks=$(docker network list --format '{{.Name}}' | grep -iE "traffic" | sort)

    for network in ${worker_networks}; do
        for machine in ${worker_machines}; do
            echo -e "Adding machine ${machine} from ${network}"
            docker network connect "${network}" "${machine}"
        done
    done
elif [ "${action}" == "delete" ]; then
    networks=$(docker network list --format '{{.Name}}' | grep -iE 'control|traffic' | sort)

    for network in ${networks}; do
        machines=$(docker network inspect "${network}" --format '{{json .Containers}}' | jq '.[].Name' | cut -f2 -d\")
        for machine in ${machines}; do
            echo -e "Removing machine ${machine} from ${network}"
            docker network disconnect --force "${network}" "${machine}"
        done
    done

elif [ "${action}" == "show" ]; then
    networks=$(docker network list --format '{{.Name}}' | grep -iE 'control|traffic' | sort)

    for network in ${networks}; do
        echo -e "\t\tIP address assignment under ${network}"
        docker network inspect "${network}" --format '{{json .Containers}}' | jq '.[] | .Name + ": " + .IPv4Address' | sort | cut -f2 -d\"
    done
else
    echo "Use Either add or delete or show for action"
fi
