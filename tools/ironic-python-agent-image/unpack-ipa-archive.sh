#!/usr/bin/env bash

#
# unpack ironic-agent-image.tar for comparison
#

set -eux

image_file="${1:?usage: $0 <ironic image tar> <output dir>}"
output_dir="${2:?usage: $0 <ironic image tar> <output dir>}"

fatal() {
    echo >&2 "error: $1"
    exit 1
}

[ ! -r "${image_file}" ] && fatal "${image_file} not found or not readable"
[ -d "${output_dir}" ] && fatal "${output_dir} already exists"

check_tool() {
    tool="${1:?no tool specified}"
    command -v "${tool}" >/dev/null || fatal "${tool} not found"
}

# check tools we need
check_tool tar
check_tool gunzip
check_tool cpio

# prepare output dir
mkdir -p "${output_dir}"
cp "${image_file}" "${output_dir}"/
cd "${output_dir}"
tar xf "${image_file}"

# check the output files (we don't do anything to kernel right now)
initramfs="ironic-python-agent.initramfs"

[ -r "${initramfs}" ] || fatal "${initramfs}: not found in output dir"

# unpack the initramfs
output_fs_dir="filesystem"
mv "${initramfs}" "${initramfs}.gz"
gunzip "${initramfs}.gz"
mkdir "${output_fs_dir}"
cd "${output_fs_dir}"
cpio -idm <../"${initramfs}"

# done
echo "initramfs extracted to: ${output_dir}/${output_fs_dir}"
