#!/bin/bash
set -eux

#install kvm for minikube
sudo apt update
sudo apt install -y qemu-kvm libvirt-clients libvirt-daemon virtinst net-tools docker firewalld

# Allow docker to run non-sudo
sudo usermod --add-subuids 200000-265536 --add-subgids 200000-265536 $(whoami)

sudo systemctl enable --now libvirtd
sudo systemctl start firewalld
sudo systemctl enable firewalld
# create provisioning network
cat <<EOF >provisioning.xml
<network
	xmlns:dnsmasq='http://libvirt.org/schemas/network/dnsmasq/1.0'>
	<dnsmasq:options>
		<!-- Risk reduction for CVE-2020-25684, CVE-2020-25685, and CVE-2020-25686. See: https://access.redhat.com/security/vulnerabilities/RHSB-2021-001 -->
		<dnsmasq:option value="cache-size=0"/>
	</dnsmasq:options>
	<name>provisioning</name>
	<bridge name='provisioning'/>
	<forward mode='bridge'></forward>
</network>
EOF

cat <<EOF >baremetal.xml
<network>
  <name>baremetal</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='baremetal' stp='on' delay='0'/>
  <ip address='192.168.222.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.222.2' end='192.168.222.199'/>
    </dhcp>
  </ip>
</network>
EOF

# define networks
for net in baremetal provisioning; do
  virsh -c qemu:///system net-define "${net}.xml"
  virsh -c qemu:///system net-start "${net}"
  virsh -c qemu:///system net-autostart "${net}"
done

# sudo cat <<EOF >/etc/NetworkManager/system-connections/provisioning.nmconnection
# [connection]
# id=provisioning
# type=bridge
# interface-name=provisioning
# [bridge]
# stp=false
# [ipv4]
# address1=172.22.0.1/24
# method=manual
# [ipv6]
# addr-gen-mode=eui64
# method=disabled
# EOF
#
# sudo chmod 600 /etc/NetworkManager/system-connections/provisioning.nmconnection
# sudo nmcli con load /etc/NetworkManager/system-connections/provisioning.nmconnection
# sudo nmcli con up provisioning
#
# sudo tee /etc/NetworkManager/system-connections/baremetal.nmconnection <<EOF
# [connection]
# id=baremetal
# type=bridge
# interface-name=baremetal
# autoconnect=true
# [bridge]
# stp=false
# [ipv6]
# addr-gen-mode=stable-privacy
# method=ignore
# EOF
#
# sudo chmod 600 /etc/NetworkManager/system-connections/baremetal.nmconnection
# sudo nmcli con load /etc/NetworkManager/system-connections/baremetal.nmconnection
# sudo nmcli con up baremetal
#
# docker pod create -n infra-pod || true
# docker pod create -n ironic-pod || true
