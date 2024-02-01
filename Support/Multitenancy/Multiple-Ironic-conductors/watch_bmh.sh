#!/bin/env bash
#
#
declare -A word_count
while true; do
    states=($(kubectl get bmh -A -o json | jq -r '.items[].status.provisioning.state'))
    word_count=()
    for word in ${states[@]}; do
        let word_count["$word"]++
    done

    status_line=""
    for word in "${!word_count[@]}"; do
        status_line="$status_line $word: ${word_count["$word"]}"
        if [[ word == "available" && ${#word_count["${word}"][@]} == ${#states[@]} ]]; then
            exit 0
        fi
    done
    echo "${status_line}"
    sleep 60
done
