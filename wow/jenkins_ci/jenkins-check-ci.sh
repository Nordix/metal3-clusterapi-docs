#!/usr/bin/env bash

set -u
# List of jobs in 'jenkins-jobs-to-scan.txt' based on
# https://github.com/Nordix/metal3-dev-tools/blob/master/wow/jenkins_ci/README.md

# remove empty lines
sed -i '/^\s*$/d' jenkins-jobs-to-scan.txt

nbr_of_lines=$(wc -l < jenkins-jobs-to-scan.txt)

count=0
all_pass=true
tput clear
tput bold

out=$(curl -s https://jenkins.nordix.org/view/Metal3%20Periodic/api/json?pretty=true | jq '.jobs[]|.color+" "+.name+" "+.url' | sort -u | grep -E "red|aborted"| column -t )
if [[ -n "${out}" ]]; then
    if [[ "${all_pass}" == true ]]; then
        tput setaf 1
        echo "--------------------------------------"
        echo "---------- FAILED CI JOBS ------------"
        echo "--------------------------------------"
        all_pass=false
    fi
    echo "${out}"
fi
if [[ "${all_pass}" == true ]]; then
    if [[ -z "${out}" ]]; then
        if [[ "${nbr_of_lines}" -eq "${count}" ]]; then
            tput setaf 2
            echo "--------------------------------------"
            echo "----- ALL REQUIRED CI JOBS PASS ------"
            echo "--------------------------------------"
        fi
    fi
fi