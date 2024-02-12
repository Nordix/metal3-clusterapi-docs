# Cleura Openstack

## Overview

Our Openstack infrastructure is provided by Cleura. The main interface is the
web UI and can be accessed [here](https://cleura.cloud). You will need
to have an account there, you can ask the team to get one.

## Accessing the Openstack API

In order to access the openstack API, you need to create a user. The web page to
do so can be accessed in the menu, API -> Native Openstack API. You then need to
add the projects to which the user will be authorized. Once done, you can
download an `openstack.rc` file for each of the projects you need to access

## Projects

We have three projects :

- **default**: The CI project, please do not create machines there
- **dev**: The developers project
- **dev2**: The second developers project

For development purposes, please use either *dev* or *dev2*

## Connectivity

In the *dev* and *dev2* projects, we have a jumphost as a bastion host. No
floating IP should be given to the VMs directly except the jumphost. All SSH
access goes through the jumphosts.

## Example SSH config

In order to access the dev VMs (`10.101.10.*` or `10.201.10.*`), the SSH traffic
needs to go through the jumphost. If you want to SSH to the jumphost itself,
please use the metal3ci account with the correct SSH key.

Replace user by your username in the following script

```bash
Host dev_jumphost
  User <user>
  IdentityFile /home/<user>/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  Hostname 188.212.109.109
Host 10.101.10.*
  User ubuntu
  IdentityFile /home/<user>/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile no
  ProxyCommand ssh  -W %h:%p dev_jumphost
Host dev2_jumphost
  User <user>
  IdentityFile /home/<user>/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  Hostname 188.95.226.253
Host 10.201.10.*
  User ubuntu
  IdentityFile /home/<user>/.ssh/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile no
  ProxyCommand ssh  -W %h:%p dev2_jumphost
```

## Create a VM

You can create the VM through the web UI or the API as you wish, as long as it
follows those rules:

- no floating IP
- port security and security group set (*default* allows only ssh as incoming
  traffic from the jumphost or other machines in the default security group).
  You can create your own security group if needed.
- sensible specs (we are sharing resources)
- network connectivity : metal3-ext-dev only , no direct connection to the
  external network
- don't use passwords but SSH keys
- delete your machine when you don't need it anymore
