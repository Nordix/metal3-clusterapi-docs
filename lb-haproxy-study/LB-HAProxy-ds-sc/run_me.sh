#!/bin/bash

hosts="master1 master2 master3"

# install k8s binaries, in case they are not installed already
for host in $hosts; do
  vagrant ssh "${host}" -- sudo chmod 700 /vagrant/setup_k8s_binaries.sh
  vagrant ssh "${host}" -- sudo /vagrant/setup_k8s_binaries.sh
  vagrant ssh "${host}" -- sudo kubeadm reset -f || true
  vagrant ssh "${host}" -- sudo rm -rf /home/vagrant/.kube/config
done

# hapxy config file to masters
for host in $hosts; do
  vagrant upload haproxy.cfg "${host}"
  vagrant ssh "${host}" -- cp /home/vagrant/haproxy.cfg /tmp/haproxy.cfg
done

# daemon set and service config
vagrant upload hapxy-ok-ds.yaml master1

# Using Kubeadm, create a cluster on master1
M1_IP=$(vagrant ssh master1 -- hostname -I | tr ' ' '\n' | grep -m1 1 | tail -n1)
if [ -z "$M1_IP" ]; then
  echo "M1 IP not set"
  exit 0
fi

M2_IP=$(vagrant ssh master2 -- hostname -I | tr ' ' '\n' | grep -m1 1 | tail -n1)
if [ -z "$M2_IP" ]; then
  echo "M2 IP not set"
  exit 0
fi

M3_IP=$(vagrant ssh master3 -- hostname -I | tr ' ' '\n' | grep -m1 1 | tail -n1)
if [ -z "$M2_IP" ]; then
  echo "M3 IP not set"
  exit 0
fi

# set backend server IP in hapxy cfg
vagrant ssh master1 -- sed -i 's/BACKEND_SERVER/'"$M1_IP"'/g' /tmp/haproxy.cfg
vagrant ssh master2 -- sed -i 's/BACKEND_SERVER/'"$M2_IP"'/g' /tmp/haproxy.cfg
vagrant ssh master3 -- sed -i 's/BACKEND_SERVER/'"$M3_IP"'/g' /tmp/haproxy.cfg

# encryption key for certs
KEY=$(openssl rand -hex 32)
vagrant ssh master1 -- cp /vagrant/config.yaml /home/vagrant/kubeadm-config.yaml
vagrant ssh master1 -- sed -i 's/CHANGE_ME/'"$M1_IP"'/g' /home/vagrant/kubeadm-config.yaml
vagrant ssh master1 -- sed -i 's/CHANGE_CERT_KEY/'"$KEY"'/g' /home/vagrant/kubeadm-config.yaml

echo "KUBEADM INIT"

vagrant ssh master1 -- sudo kubeadm init --upload-certs --config=/home/vagrant/kubeadm-config.yaml | tee init_results.txt
grep -A4 'To start using your cluster'  < init_results.txt | tail -n 3 > masters_kubeconfig.sh

# configure kubeconfig on master1
vagrant upload masters_kubeconfig.sh master1
vagrant ssh master1 -- chmod 700 masters_kubeconfig.sh
vagrant ssh master1 -- ./masters_kubeconfig.sh

# join, worker join not used on purpose
TOKEN="$(vagrant ssh master1 -- kubeadm token generate)"
JOIN_WORKER="$(vagrant ssh master1 -- sudo kubeadm token create "${TOKEN}" --print-join-command)"
JOIN_MASTER="${JOIN_WORKER} --control-plane --certificate-key ${KEY}"

# configure kubeconfig and run join command on master2 and master3
for host in master2 master3;do
  echo "KUBEADM JOIN " $host
   vagrant upload masters_kubeconfig.sh $host
   vagrant ssh $host -- chmod 700 masters_kubeconfig.sh
   vagrant ssh $host -- sudo "${JOIN_MASTER}"
   vagrant ssh $host -- ./masters_kubeconfig.sh
done

# set up pods networking on any of the masters
vagrant ssh master1 -- kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml

# copy kubeconfig file from one of the masters and run kubectl get nodes
mkdir -p "${HOME}"/.kube || true
rm -f config.txt
vagrant ssh-config > config.txt
scp -F config.txt master1:/home/vagrant/.kube/config "${HOME}"/.kube/config
echo "Wait until nodes are ready, <ctrl-c> to break"
kubectl get nodes -w
