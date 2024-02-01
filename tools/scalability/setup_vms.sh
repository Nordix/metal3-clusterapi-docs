#!/bin/bash

# This script assumes that the IPs of the vms are given
# in the vm_ip_list.txt. Please follow the same example as
# given in the file. Also the assumption is that the whole
# setup in metal3-dev-env is done on ubuntu based setup.
# It is also assumed that the first IP is the master vm IP

set -eux

vm_id=1
ips=$(tr '\n' ' ' < vm_ip_list.txt)


for ip in $ips
do
	ssh ubuntu@"${ip}" -- " rm -rf metal3-dev-env/ && \
 	git clone https://github.com/Nordix/metal3-dev-env.git && \
 	cd metal3-dev-env/ && \
 	git checkout ironic-scalability-host1 && \
 	echo "export IMAGE_OS=Ubuntu" >> /home/ubuntu/metal3-dev-env/config_example.sh && \
	echo "export CONTAINER_RUNTIME=docker" >> /home/ubuntu/metal3-dev-env/config_example.sh && \
 	echo "export EPHEMERAL_CLUSTER=kind" >> /home/ubuntu/metal3-dev-env/config_example.sh && \
 	echo "export VM_ID=${vm_id}" >> /home/ubuntu/metal3-dev-env/config_example.sh && \
	echo "export NUM_VMS=4" >> /home/ubuntu/metal3-dev-env/config_example.sh && \
 	echo "export NUM_NODES=6"  >> /home/ubuntu/metal3-dev-env/config_example.sh && \
 	make scalability" &

 	vm_id=$(( vm_id + 1 ))

done
wait

master_vm_ip=$(head -n 1 vm_ip_list.txt)

for ip in $ips;do

	if [[ "${ip}" == "${master_vm_ip}" ]]; then
		ssh ubuntu@"${ip}" -- "mkdir bm_crs"
		continue
	fi
	scp ubuntu@"${ip}":/opt/metal3-dev-env/bmhosts_crs.yaml /tmp/bm_crs_"${ip}".yaml
	scp /tmp/bm_crs_"${ip}".yaml ubuntu@"${master_vm_ip}":/home/ubuntu/bm_crs/
done

ssh ubuntu@"${master_vm_ip}" -- "kubectl apply -n metal3 -f /home/ubuntu/bm_crs/"
ssh ubuntu@"${master_vm_ip}" -- 'cd metal3-dev-env/ && bash -c /home/$USER/metal3-dev-env/provision_image.sh'
