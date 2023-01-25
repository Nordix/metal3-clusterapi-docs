set -e
virsh attach-interface --domain minikube --model virtio --source provisioning --type network --config
virsh attach-interface --domain minikube --model virtio --source provisioning --type network --config
virsh attach-interface --domain minikube --model virtio --source baremetal --type network --config
# Download images
podman run -d -p 5000:5000 --name registry docker.io/library/registry:2.7.1
# Create pods 
podman pod create -n infra-pod || true
podman pod create -n ironic-pod || true
# Pull images
mkdir -p /opt/metal3-dev-env/ironic/html/images
podman pull quay.io/metal3-io/sushy-tools
podman pull quay.io/metal3-io/ironic-ipa-downloader
podman pull quay.io/metal3-io/ironic:latest
podman pull quay.io/metal3-io/ironic-client
podman pull quay.io/metal3-io/keepalived
podman tag quay.io/metal3-io/sushy-tools 127.0.0.1:5000/localimages/sushy-tools
podman tag quay.io/metal3-io/ironic-ipa-downloader 127.0.0.1:5000/localimages/ironic-ipa-downloader
podman tag quay.io/metal3-io/ironic-client 127.0.0.1:5000/localimages/ironic-client
podman tag quay.io/metal3-io/keepalived 127.0.0.1:5000/localimages/keepalived
podman tag quay.io/metal3-io/ironic:latest 127.0.0.1:5000/localimages/ironic:latest
podman push --tls-verify=false 127.0.0.1:5000/localimages/keepalived
podman push --tls-verify=false 127.0.0.1:5000/localimages/ironic-client
podman push --tls-verify=false 127.0.0.1:5000/localimages/ironic:latest
podman push --tls-verify=false 127.0.0.1:5000/localimages/ironic-ipa-downloader
podman push --tls-verify=false 127.0.0.1:5000/localimages/sushy-tools
# Run host services
# Run httpd
podman run -d --net host --name httpd-infra --pod infra-pod -v /opt/metal3-dev-env/ironic:/shared -e PROVISIONING_INTERFACE=provisioning -e LISTEN_ALL_INTERFACES=false --entrypoint /bin/runhttpd 127.0.0.1:5000/localimages/ironic:latest
# Run sushy-tools 
mkdir /opt/metal3-dev-env/ironic/virtualbmc
mkdir /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools
chmod -R 755 /opt/metal3-dev-env/ironic/virtualbmc

cat <<EOF > /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools/conf.py
SUSHY_EMULATOR_LIBVIRT_URI = "qemu+ssh://root@192.168.111.1/system?&keyfile=/root/ssh/id_rsa_virt_power&no_verify=1&no_tty=1"
SUSHY_EMULATOR_IGNORE_BOOT_DEVICE = False
SUSHY_EMULATOR_VMEDIA_VERIFY_SSL = False
SUSHY_EMULATOR_AUTH_FILE = "/root/sushy/htpasswd"
SUSHY_EMULATOR_FAKE_DRIVER = True
EOF
cat <<'EOF' > /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools/htpasswd
admin:$2b$12$/dVOBNatORwKpF.ss99KB.vESjfyONOxyH.UgRwNyZi1Xs/W2pGVS
EOF
ssh-keygen -f /root/.ssh/id_rsa_virt_power -P ""
/root/.ssh/id_rsa_virt_power.pub | tee -a /root/.ssh/authorized_keys
podman run -d --net host --name sushy-tools --pod infra-pod      -v /opt/metal3-dev-env/ironic/virtualbmc/sushy-tools:/root/sushy -v "/root/.ssh":/root/ssh      127.0.0.1:5000/localimages/sushy-tools
