#!/bin/bash

set -eux

# Given the root of a directory tree
#       It gathers folders that contain kustomization.yaml file
#       It removes files based on the content of the kustomization.yaml file
#       It removes kustomiz* files and folder
function trim_repos() {
    # Remove unneeded files
    for k_file_path in $(find "${1}" -type f | grep "kustomization.yaml"); do
        handle_patch_files "${k_file_path}"
    done
    # Remove empty folders AND kustomiz*.yaml files
    for any_folder in $(find "${1}" -type d); do
        cleanup "${any_folder}"
    done
}

# Given a folder path, it removes empty folders, kustomization and KustomizeConfig files
function cleanup() {
    current_folder="${1}"

    # remove kustomz*.yaml file, no matter what
    pushd $current_folder
    rm -rf kustomization.yaml kustomizeconfig.yaml
    popd

    if [ -z "$(ls -A ${current_folder})" ]; then
        rm -rf "${current_folder}"
    fi

    #fi
    # Add more items to be removed here
    # One example is duplicate resources

}

# Give a kustomization file, it finds patch files and removs them
# input: a path to a kustomization.yaml file that do not serve as basis

function handle_patch_files() {
    # https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#kustomize-feature-list
    # patchesStrategicMerge
    # patchesJson6902
    k_file="${1}"

    k_folder="$(dirname ${1})"
    k_file="$(readlink -f ${1})"

    pushd "${k_folder}"

    if grep -q "patchesStrategicMerge:" "${k_file}"; then
        cat "${k_file}" | grep -A123456789 'patchesStrategicMerge:' | grep -v 'patchesStrategicMerge:' >/tmp/starting.txt
    elif grep -q "patchesJson6902:" "${k_file}"; then
        cat "${k_file}" | grep -A123456789 'patchesJson6902:' | grep -v 'patchesJson6902:' >/tmp/starting.txt
    fi
    # if bases or resources was the last item in the yaml file, then skip
    if grep -q ":" "/tmp/starting.txt"; then
        files_to_be_removed="$(cat /tmp/starting.txt | grep -B12345678 ':' | grep -v ':')"
    else
        # This is the last block in the yaml
        files_to_be_removed="$(cat /tmp/starting.txt | grep -v "#" | grep '-' | tr '-' ' ')"
    fi

    # removal works because kustomization file includes the files relatively
    # covers both - and - ../some/path
    for f in $files_to_be_removed; do
        # if file already is removed or not present, keep quite
        # if this is a folder, do not do anything

        if [ ! -d "$f" ]; then
            rm -f "${f}"
        fi
    done
    popd
}

# Removes un-needed folders and files
# input: A path to the root of the tree

if [ $# -ne 1 ]; then
  echo 1>&2 "Usage: $0 <path to the folder containing all repos>"
  exit 3
fi
trim_repos "${1}"
