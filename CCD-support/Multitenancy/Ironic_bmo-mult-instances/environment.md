# Ironic and BMO multitenancy environment

Steps to run multiple instance of ironic and bmo in a capm3 management cluster.

## Requirements

Machine: `4c / 16gb / 100gb`
OS: `CentOS9-20220330`

## VM Setup

1. Install libvirt

    ```bash
    sudo su
    dnf -y install qemu-kvm libvirt virt-install
    systemctl enable --now libvirtd
    ```

2. Create a pool

    `mkdir /opt/mypool`

    ```xml
    cat <<EOF > /opt/mypool/mypool.xml
    <pool type='dir'>
    <name>mypool</name>
    <target>
     <path>/opt/mypool</path>
    </target>
    </pool>
    EOF

    virsh pool-define /opt/mypool/mypool.xml
    virsh pool-start mypool
    virsh pool-autostart mypool
    virsh vol-create-as mypool node-1.qcow2 30G --format qcow2
    virsh vol-create-as mypool node-2.qcow2 30G --format qcow2
    ```

3. Create provisioning network

    ```bash
    cat <<EOF > provisioning-1.xml
    <network
     xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
     <dnsmasq:options>
      <!-- Risk reduction for CVE-2020-25684, CVE-2020-25685, and CVE-2020-25686. See: https://access.redhat.com/security/vulnerabilities/RHSB-2021-001 -->
      <dnsmasq:option value="cache-size=0"/>
     </dnsmasq:options>
     <name>provisioning-1</name>
     <bridge name='provisioning-1'/>
     <forward mode='bridge'></forward>
    </network>
    EOF

    cat <<EOF > provisioning-2.xml
    <network
     xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
     <dnsmasq:options>
      <!-- Risk reduction for CVE-2020-25684, CVE-2020-25685, and CVE-2020-25686. See: https://access.redhat.com/security/vulnerabilities/RHSB-2021-001 -->
      <dnsmasq:option value="cache-size=0"/>
     </dnsmasq:options>
     <name>provisioning-2</name>
     <bridge name='provisioning-2'/>
     <forward mode='bridge'></forward>
    </network>
    EOF

    cat <<EOF > baremetal.xml
    <network xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
      <name>baremetal</name>
      <forward mode='nat'>
        <nat>
          <port start='1024' end='65535'/>
        </nat>
      </forward>
      <bridge name='baremetal' stp='on' delay='0'/>
      <domain name='ostest.test.metalkube.org' localOnly='yes'/>
      <dns>
        <forwarder domain='apps.ostest.test.metalkube.org' addr='127.0.0.1'/>
      </dns>
      <ip address='192.168.111.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.111.20' end='192.168.111.60'/>
          <host mac='00:5c:52:31:3b:9c' name='node-0' ip='192.168.111.20'>
            <lease expiry='60' unit='minutes'/>
          </host>
          <host mac='00:5c:52:31:3b:ad' name='node-1' ip='192.168.111.21'>
            <lease expiry='60' unit='minutes'/>
          </host>
        </dhcp>
      </ip>
      <dnsmasq:options>
        <dnsmasq:option value='cache-size=0'/>
      </dnsmasq:options>
    </network>
    EOF

    virsh net-define provisioning-1.xml
    virsh net-define provisioning-2.xml
    virsh net-define baremetal.xml

    virsh net-start provisioning-1
    virsh net-start provisioning-2
    virsh net-start baremetal

    virsh net-autostart provisioning-1
    virsh net-autostart provisioning-2
    virsh net-autostart baremetal

    yum install net-tools

    # Create bridges
    echo -e "DEVICE=provisioning-1\nTYPE=Bridge\nONBOOT=yes\nBOOTPROTO=static\nIPADDR=172.22.0.1\nNETMASK=255.255.255.0" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-provisioning-1
    echo -e "DEVICE=provisioning-2\nTYPE=Bridge\nONBOOT=yes\nBOOTPROTO=static\nIPADDR=172.23.0.1\nNETMASK=255.255.255.0" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-provisioning-2
    echo -e "DEVICE=baremetal\nTYPE=Bridge\nONBOOT=yes\n" | sudo dd of=/etc/sysconfig/network-scripts/ifcfg-baremetal
    sudo systemctl restart NetworkManager.service
    # check that the interface is up if down turn it up
    ```

4. Define libvirt domains

    ```bash
    cat <<EOF > node-1.xml
    <domain type='kvm'>
     <name>node-1</name>
     <memory unit='MiB'>8000</memory>
     <vcpu>2</vcpu>
     <os>
      <type arch='x86_64' machine='q35'>hvm</type>
      <nvram>/var/lib/libvirt/qemu/nvram/node-1.fd</nvram>
      <boot dev='network'/>
      <bootmenu enable='no'/>
     </os>
     <features>
      <acpi/>
      <apic/>
      <pae/>
     </features>
     <cpu mode='host-passthrough'/>
     <clock offset='utc'/>
     <on_poweroff>destroy</on_poweroff>
     <on_reboot>restart</on_reboot>
     <on_crash>restart</on_crash>
     <devices>
      <disk type='volume' device='disk'>
       <driver name='qemu' type='qcow2' cache='unsafe'/>
       <source pool='mypool' volume='node-1.qcow2'/>
       <target dev='sda' bus='scsi'/>
      </disk>
      <controller type='scsi' model='virtio-scsi' />
      <interface type='bridge'>
       <mac address='00:5c:52:31:3a:9c'/>
       <source bridge='provisioning-1'/>
       <model type='virtio'/>
      </interface>
      <interface type='bridge'>
       <mac address='00:5c:52:31:3b:9c'/>
       <source bridge='baremetal'/>
       <model type='virtio'/>
      </interface>
      <console type='pty'/>
      <input type='mouse' bus='ps2'/>
      <graphics type='vnc' port='-1' autoport='yes'/>
      <video>
       <model type='cirrus' vram='9216' heads='1'/>
      </video>
     </devices>
    </domain>
    EOF
    cat <<EOF > node-2.xml
    <domain type='kvm'>
     <name>node-2</name>
     <memory unit='MiB'>8000</memory>
     <vcpu>2</vcpu>
     <os>
      <type arch='x86_64' machine='q35'>hvm</type>
      <nvram>/var/lib/libvirt/qemu/nvram/node-2.fd</nvram>
      <boot dev='network'/>
      <bootmenu enable='no'/>
     </os>
     <features>
      <acpi/>
      <apic/>
      <pae/>
     </features>
     <cpu mode='host-passthrough'/>
     <clock offset='utc'/>
     <on_poweroff>destroy</on_poweroff>
     <on_reboot>restart</on_reboot>
     <on_crash>restart</on_crash>
     <devices>
      <disk type='volume' device='disk'>
       <driver name='qemu' type='qcow2' cache='unsafe'/>
       <source pool='mypool' volume='node-2.qcow2'/>
       <target dev='sda' bus='scsi'/>
      </disk>
      <controller type='scsi' model='virtio-scsi' />
      <interface type='bridge'>
       <mac address='00:5c:52:31:3a:ad'/>
       <source bridge='provisioning-2'/>
       <model type='virtio'/>
      </interface>
      <interface type='bridge'>
       <mac address='00:5c:52:31:3b:ad'/>
       <source bridge='baremetal'/>
       <model type='virtio'/>
      </interface>
      <console type='pty'/>
      <input type='mouse' bus='ps2'/>
      <graphics type='vnc' port='-1' autoport='yes'/>
      <video>
       <model type='cirrus' vram='9216' heads='1'/>
      </video>
     </devices>
    </domain>
    EOF

    virsh define node-1.xml
    virsh define node-2.xml
    ```

## Install minikube

```bash
curl -LO https://storage.googleapis.com/minikube/releases/v1.25.2/minikube-linux-amd64
install minikube-linux-amd64 /usr/local/bin/minikube
# Run minikube commands with non root user
minikube config set driver kvm2
minikube config set memory 4096

usermod --append --groups libvirt `whoami`

minikube start  --insecure-registry 172.22.0.1:5000
minikube stop

virsh attach-interface --domain minikube --model virtio --source provisioning-1 --type network --config
virsh attach-interface --domain minikube --model virtio --source provisioning-2 --type network --config
virsh attach-interface --domain minikube --model virtio --source baremetal --type network --config
```

## Download images to the local registry

1. Run registry on port 5000

    ```bash
    podman run -d -p 5000:5000 --name registry docker.io/library/registry:2.7.1
    ```

2. Create pods

    ```bash
    podman pod create -n infra-pod
    podman pod create -n ironic-pod
    ```

3. Create ironic images folder

    ```bash
    mkdir -p /opt/ironic/html/images
    ```

4. Pull images

    ```bash
    podman pull quay.io/metal3-io/vbmc
    podman pull quay.io/metal3-io/sushy-tools
    podman pull quay.io/metal3-io/ironic-ipa-downloader
    podman pull quay.io/metal3-io/ironic:latest
    podman pull quay.io/metal3-io/ironic-client
    podman pull quay.io/metal3-io/keepalived
    podman pull quay.io/metal3-io/baremetal-operator
    ```

5. Tag images

    ```bash
    podman tag quay.io/metal3-io/vbmc 127.0.0.1:5000/localimages/vbmc
    podman tag quay.io/metal3-io/sushy-tools 127.0.0.1:5000/localimages/sushy-tools
    podman tag quay.io/metal3-io/ironic-ipa-downloader 127.0.0.1:5000/localimages/ironic-ipa-downloader
    podman tag quay.io/metal3-io/ironic-client 127.0.0.1:5000/localimages/ironic-client
    podman tag quay.io/metal3-io/keepalived 127.0.0.1:5000/localimages/keepalived
    podman tag quay.io/metal3-io/ironic:latest 127.0.0.1:5000/localimages/ironic:latest
    podman tag quay.io/metal3-io/baremetal-operator:latest 127.0.0.1:5000/localimages/baremetal-operator:latest
    ```

6. Tag images

    ```bash
    podman push --tls-verify=false 127.0.0.1:5000/localimages/keepalived
    podman push --tls-verify=false 127.0.0.1:5000/localimages/ironic-client
    podman push --tls-verify=false 127.0.0.1:5000/localimages/ironic:latest
    podman push --tls-verify=false 127.0.0.1:5000/localimages/ironic-ipa-downloader
    podman push --tls-verify=false 127.0.0.1:5000/localimages/sushy-tools
    podman push --tls-verify=false 127.0.0.1:5000/localimages/vbmc
    podman push --tls-verify=false 127.0.0.1:5000/localimages/baremetal-operator:latest
    ```

## Run host services

1. Run httpd

    ```bash
    podman run -d --net host --name httpd-infra --pod infra-pod -v /opt/ironic:/shared -e PROVISIONING_INTERFACE=provisioning-1 -e LISTEN_ALL_INTERFACES=false --entrypoint /bin/runhttpd 127.0.0.1:5000/localimages/ironic:latest

    podman run -d --net host --name httpd-infra2 --pod infra-pod -v /opt/ironic:/shared -e PROVISIONING_INTERFACE=provisioning-2 -e LISTEN_ALL_INTERFACES=false --entrypoint /bin/runhttpd 127.0.0.1:5000/localimages/ironic:latest
    ```

2. Run vbmc and sushy-tools

    ```bash
    mkdir /opt/ironic/virtualbmc
    mkdir /opt/ironic/virtualbmc/vbmc
    mkdir /opt/ironic/virtualbmc/vbmc/conf
    mkdir /opt/ironic/virtualbmc/vbmc/log
    mkdir /opt/ironic/virtualbmc/sushy-tools

    cat <<EOF >> /opt/ironic/virtualbmc/vbmc/virtualbmc.conf
    [default]
    config_dir=/root/.vbmc/conf/
    [log]
    logfile=/root/.vbmc/log/virtualbmc.log
    debug=True
    [ipmi]
    session_timout=20
    EOF

    # Create nodes configuration
    # create a dir for each node
    mkdir -p /opt/ironic/virtualbmc/vbmc/conf/node-1
    mkdir -p /opt/ironic/virtualbmc/vbmc/conf/node-2

    # add config for each
    cat <<EOF > /opt/ironic/virtualbmc/vbmc/conf/node-1/config
    [VirtualBMC]
    username = admin
    password = password
    domain_name = node-1
    libvirt_uri = qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1
    address = 192.168.111.1
    active = True
    port =  6230
    EOF

    cat <<EOF > /opt/ironic/virtualbmc/vbmc/conf/node-2/config
    [VirtualBMC]
    [VirtualBMC]
    username = admin
    password = password
    domain_name = node-2
    libvirt_uri = qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1
    address = 192.168.111.1
    active = True
    port =  6231
    EOF

    cat <<EOF > /opt/ironic/virtualbmc/sushy-tools/conf.py
    SUSHY_EMULATOR_LIBVIRT_URI = "qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
    SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = False
    SUSHY_EMULATOR_VMEDIA_VERIFY_SSL = False
    SUSHY_EMULATOR_AUTH_FILE = "/root/sushy/htpasswd"
    EOF

    cat <<'EOF' > /opt/ironic/virtualbmc/sushy-tools/htpasswd
    admin:$2b$12$/dVOBNatORwKpF.ss99KB.vESjfyONOxyH.UgRwNyZi1Xs/W2pGVS
    EOF

    ssh-keygen -f /root/.ssh/id_rsa_virt_power -P ""
    cat /root/.ssh/id_rsa_virt_power.pub | tee -a /root/.ssh/authorized_keys

    podman run -d --net host --name vbmc --pod infra-pod \
         -v /opt/ironic/virtualbmc/vbmc:/root/.vbmc -v "/root/.ssh":/root/ssh \
         127.0.0.1:5000/localimages/vbmc

    podman run -d --net host --name sushy-tools --pod infra-pod \
         -v /opt/ironic/virtualbmc/sushy-tools:/root/sushy -v "/root/.ssh":/root/ssh \
         127.0.0.1:5000/localimages/sushy-tools
    ```

3. Check containers are running

    ```bash
    podman ps
    ```

4. Add vbmc client

    ```bash
    cat <<'EOF' > vbmc.sh
    #!/bin/bash
    sudo podman exec -ti vbmc vbmc "$@"
    EOF

    chmod a+x vbmc.sh
    sudo ln -sf $PWD/vbmc.sh /usr/local/bin/vbmc
    ```

5. Check and play with vbmc

    ```bash
    vbmc list
    +-------------+---------+---------------+------+
    | Domain name | Status  | Address       | Port |
    +-------------+---------+---------------+------+
    | node-1      | running | 192.168.111.1 | 6230 |
    | node-2      | running | 192.168.111.1 | 6231 |
    +-------------+---------+---------------+------+

    yum install OpenIPMI ipmitool

    ipmitool -I lanplus -U admin -P password -H 192.168.111.1 -p 6230 power on

    # Check the domain is running on virsh
    virsh list --all
    ```

## Run management cluster

1. Start minikube

    ```bash
    minikube start --insecure-registry 172.22.0.1:5000

    # test create a deployment with image from the local registry
    kubectl create deployment hello-node --image=172.22.0.1:5000/localimages/ironic-client

    # check the image was pulled successfully
    minikube ssh

    sudo brctl addbr ironicendpoint
    sudo ip link set ironicendpoint up
    sudo brctl addif  ironicendpoint eth2
    sudo ip addr add 172.22.0.2/24 dev ironicendpoint

    sudo brctl addbr ironicendpoint2
    sudo ip link set ironicendpoint2 up
    sudo brctl addif  ironicendpoint2 eth3
    sudo ip addr add 172.23.0.2/24 dev ironicendpoint2
    ```

## Firewall

```bash
firewall-cmd  --zone=libvirt  --add-port=6230/udp
firewall-cmd  --zone=libvirt  --add-port=6231/udp
```

## Run ironic

1. Launch ironic instance

    From the manifest [ironic-ns.yaml](ironic-ns.yaml)

2. Apply ironic in two different ns:

    ```bash
    kubectl apply -f ironic-1.yaml -n baremetal-operator-system-test1
    kubectl apply -f ironic-2.yaml -n baremetal-operator-system-test2
    ```

3. Create Ironic client

    ```bash
    cat <<'EOF' > ironicclient.sh
    #!/bin/bash

    DIR="$(dirname "$(readlink -f "$0")")"

    if [ -d "${PWD}/_clouds_yaml" ]; then
      MOUNTDIR="${PWD}/_clouds_yaml"
    else
      echo "cannot find _clouds_yaml"
      exit 1
    fi

    if [ "$1" == "baremetal" ] ; then
      shift 1
    fi

    # shellcheck disable=SC2086
    sudo podman run --net=host --tls-verify=false \
      -v "${MOUNTDIR}:/etc/openstack" --rm \
      -e OS_CLOUD="${OS_CLOUD:-metal3}" "172.22.0.1:5000/localimages/ironic-client" "$@"
    EOF

    mkdir _clouds_yaml

    cat <<'EOF' > _clouds_yaml/clouds.yaml
    clouds:
      metal3:
        auth_type: none
        baremetal_endpoint_override: http://172.22.0.2:6385
        baremetal_introspection_endpoint_override: http://172.22.0.2:5050
    EOF
    sudo ln -sf "/home/metal3ci/ironicclient.sh" "/usr/local/bin/baremetal"
    ```

## Run BMO

1. install cert manager

    ```bash
    wget https://github.com/cert-manager/cert-manager/releases/download/v1.5.3/cert-manager.yaml
    kubectl apply -f cert-manager.yaml
    ```

    From the manifest [bmo-wns.yaml](bmo-wns.yaml)

2. Apply bmo in two different ns:

    ```bash
    kubectl apply -f bmo-1.yaml -n baremetal-operator-system-test1
    kubectl apply -f bmo-2.yaml -n baremetal-operator-system-test2
    kubectl create ns test1
    kubectl create ns test2
    kubectl apply -f role.yaml -n test1
    kubectl apply -f role-binding.yaml -n test1
    kubectl apply -f role-2.yaml -n test2
    kubectl apply -f role-binding-2.yaml -n test
    ```

3. Creating bmhs

    ```yaml
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: node-0-bmc-secret
    type: Opaque
    data:
      username: YWRtaW4=
      password: cGFzc3dvcmQ=

    ---
    apiVersion: metal3.io/v1alpha1
    kind: BareMetalHost
    metadata:
      name: node-0
    spec:
      online: true
      bootMACAddress: 00:5c:52:31:3a:9c
      bootMode: legacy
      bmc:
        address: ipmi://192.168.111.1:6230
        credentialsName: node-0-bmc-secret
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: node-1-bmc-secret
    type: Opaque
    data:
      username: YWRtaW4=
      password: cGFzc3dvcmQ=

    ---
    apiVersion: metal3.io/v1alpha1
    kind: BareMetalHost
    metadata:
      name: node-1
    spec:
      online: true
      bootMACAddress: 00:5c:52:31:3a:ad
      bootMode: legacy
      bmc:
        address: ipmi://192.168.111.1:6231
        credentialsName: node-1-bmc-secret

    ```

    ```bash
    kubectl get bmh -A

    NAMESPACE   NAME     STATE          CONSUMER                   ONLINE   ERROR   AGE
    test1       node-1   available                                  true            3m
    test2       node-2   available                                  true            2m
    ```

## Init the management cluster

1. Get clusterctl

    ```bash
    curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.5/clusterctl-linux-amd64 -o clusterctl
    chmod +x ./clusterctl
    sudo mv ./clusterctl /usr/local/bin/clusterctl
    ```

2. Run capi/capm3

    ```bash
    clusterctl init --core cluster-api:v1.1.5 --bootstrap kubeadm:v1.1.5 --control-plane kubeadm:v1.1.5 --infrastructure=metal3:v1.1.2 -v5
    ```

## Apply cluster templates for each namespace

Make sure the networks are correct for each and use different cluster endpoint ip for each cluster since they still share the same baremetal network
