# README

The `setup_vms.sh` does the following:

- Reads the ips of the vms from the list
- clones `metal3-dev-env` in each vm,
- checks out to the scalability git branch
- exports the correct environment variables according to the vm role
- performs `make scalability`. This includes
   - typical `metal3-dev-env` `make` operation (excluding 04 script)
   - setting up the overlay networks
- waits until all the vms have the ready dev environment
- copies the bmh CRs from all the vms to the master vm
- applies the bmh CRs in master vm's Ephemeral cluster
- edits the applied BMH CRs in place to add image in spec which triggers
provisioning.

## Important note

The `vm_ip_list.txt` contains the ips of the vms. Note that the `setup_vms.sh`
assumes the first ip in this list would be the ip of the master vm. The rest
should be worker vms and can be in any order.
