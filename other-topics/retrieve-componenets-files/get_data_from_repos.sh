#!/bin/bash
# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -eux

# Set specific release
BMO_RELEASE="${BMO_RELEASE:-master}"
CAPI_RELEASE="${CAPI_RELEASE:-master}" # the same as CABPK
CAPBM_RELEASE="${CAPBM_RELEASE:-master}"

# Directories
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
OUTPUT_DIR=${1:-${SOURCE_DIR}/_bases}
CLONE_DIR=/tmp/collectrepos

# Starting point for traversing the directory structure for each repo.
base_capi="${OUTPUT_DIR}/capi"
base_bmo="${OUTPUT_DIR}/bmo"
base_capbm="${OUTPUT_DIR}/capbm"
base_cabpk="${OUTPUT_DIR}/cabpk"

# Remove old repo data
rm -rf ${CLONE_DIR} && mkdir ${CLONE_DIR}

# Clone repos to a temporary directory
pushd ${CLONE_DIR}
git clone https://github.com/metal3-io/cluster-api-provider-baremetal.git
pushd cluster-api-provider-baremetal
git checkout "${CAPBM_RELEASE}"
popd
git clone https://github.com/metal3-io/baremetal-operator.git
pushd  baremetal-operator
git checkout "${BMO_RELEASE}"
popd
git clone https://github.com/kubernetes-sigs/cluster-api.git
pushd cluster-api
git checkout "${CAPI_RELEASE}"
popd
popd

# remove old output data
rm -rf "${OUTPUT_DIR}"

mkdir -p "${base_capi}" "${base_bmo}" "${base_capbm}" "${base_cabpk}"

# Copy directory structure containing relevant yaml files
cp -r "${CLONE_DIR}/cluster-api/config/." "${base_capi}"
cp -r "${CLONE_DIR}/cluster-api/controlplane/kubeadm/config/." "${base_cabpk}" # cabbk
cp -r "${CLONE_DIR}/baremetal-operator/deploy/." "${base_bmo}"
cp -r "${CLONE_DIR}/cluster-api-provider-baremetal/config/." "${base_capbm}"

# Replace all variables to their string version, example:
# $(VAR_NAME) => VAR_NAME
find "${OUTPUT_DIR}" -type f -exec sed -i "s/\$(\([^)]*\))/\1/g" {} \;
