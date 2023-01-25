

sudo nmcli con delete baremetal
sudo nmcli con delete provisioning
sudo nmcli con delete provisioning

sudo virsh net-undefine provisioning
sudo virsh net-undefine baremetal

sudo virsh net-destroy baremetal
sudo virsh net-destroy  provisioning

sudo ip link set provisioning down
sudo ip link set provisioning down
sudo ip link set baremetal down
sudo brctl delbr baremetal
sudo brctl delbr provisioning
sudo brctl delbr provisioning
#sudo rm -rf /opt/metal3-dev-env
sudo rm -rf /opt/metal3-dev-env/ironic/virtualbmc/
sudo podman stop -a
sudo podman rmi "$(sudo podman images -qa)" -f

minikube stop
minikube delete --all --purge
