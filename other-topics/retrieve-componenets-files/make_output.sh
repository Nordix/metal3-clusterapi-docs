#!/bin/bash

set -eux

base_folder="/home/anwarh/go/src/github.com/airship-clusterapi-docs/other-topics/retrieve-componenets-files/_bases"

# make directories
mkdir -p yaml_root/provider-components/managers/{capi,cabpm,bmo,capbk}
mkdir -p yaml_root/provider-components/crds/{capi,cabpm,bmo,capbk}
mkdir -p yaml_root/infra_crs/{capi,cabpm,bmo,capbk}

# copy crds from each repo
for repo in $(ls "${base_folder}");do
    cp -r ${repo}/crd yaml_root/provider-components/managers/
    echo $repo
done

# fix naming so that copying becomes easy

# metadata.name




#base_capi="${OUTPUT_DIR}/capi"