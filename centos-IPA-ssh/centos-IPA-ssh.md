# Enable SSH to centos IPA node using dynamic-login feature

## Goal of the documentation

This documentation describes the possibility to SSH from host to centos IPA node using dynamic-login feature in IPA image builing. Here the SSH key is given to the ironic-api and ironic-conductor which eventually pass it to the IPA node and enable the user to do the ssh to the IPA node.

## Setup Environment and Testing

### Step 1
The steps in the examples were performed in Metal3 development environment that had bare metal host in ready state. `Ironic-api` and `ironic-conductor` containers were running as a docker container. After `docker exec`, first install an editor in the container to edit the ironic.conf.j2 file to add the ssh-key in both containers.
       
       docker exec -it ironic-api /bin/bash
       dnf update
       dnf install vim

Edit `ironic.conf.j2` file resides in `/etc/ironic/` in the following line:

       pxe_append_params = nofb nomodeset vga=normal ipa-insecure=1 {% if env.IRONIC_RAMDISK_SSH_KEY %}sshkey="{{ env.IRONIC_RAMDISK_SSH_KEY|trim }}"{% endif %} {{ env.IRONIC_KERNEL_PARAMS|trim }}

Add user's host `sshkey` inside double quote`("")` from `.ssh/id_rsa.pub` file and edit the line:

       pxe_append_params = nofb nomodeset vga=normal ipa-insecure=1 sshkey="ssh-rsa ...." {{ env.IRONIC_KERNEL_PARAMS|trim }}

It is alos possible to pass that sshkey using the envirnment variable. The next step is to restart the `ironic-api` container. Also user should to do the same step with `ironic-conductor` container and restart that container too. After restart verify the `sshkey` from `/etc/ironic/ironic.conf` file in both containers. The ironic.conf file will get new `sshkey` from `ironic.conf.j2` template file.
        
### Step 2
Previously `sshkey` was given to both containers and now re-inspect the desired or all bare metal host and it will allow ironic to pass the `sshkey` to IPA node. 
List of bare metal hosts:
       
       NAMESPACE NAME   STATE CONSUMER ONLINE
       metal3    node-0 ready          true
       metal3    node-1 ready          true
       metal3    node-2 ready          true
       metal3    node-3 ready          true

The following command will re-inspect `node-0` and will take few minutes to inspect:
       
       kubectl annotate bmh node-0 -n metal3 inspect.metal3.io=

list all the baremetal host IPs:

       Expiry      Time    MAC address       Protocol IP address        Hostname 
       2021-10-11 13:08:17 00:60:94:22:85:b2 ipv4     192.168.111.20/24 node-0 
       2021-10-11 13:12:35 00:60:94:22:85:b6 ipv4     192.168.111.21/24 node-1 
       2021-10-11 13:17:43 00:60:94:22:85:ba ipv4     192.168.111.22/24 node-2 
       2021-10-11 13:15:30 00:60:94:22:85:be ipv4     192.168.111.23/24 node-3

### Step 3
SSH to the `node-0` which has default username `root`: 

       ssh root@192.168.111.20

This should enable user to SSH to that IPA node and can check more info from `/var/log/` folder and can check the content of `messages` which has more detail informtation regarding IPA node. If necessary, repeat `Step 2` for other IPA node and that will allow to SSH to that IPA node.

## More Information
1. [Ironic and IPA image building process](https://github.com/Nordix/airship-dev-tools/blob/master/wow/ipa-ironic-build.md)
2. [IPA-builder SSH access](https://docs.openstack.org/ironic-python-agent-builder/latest/admin/dib.html#ssh-access)
3. [Troubleshooting IPA](https://docs.openstack.org/ironic-python-agent/latest/admin/troubleshooting.html)