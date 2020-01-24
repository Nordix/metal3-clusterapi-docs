ln -s /haproxy/haproxy.cfg  /etc/haproxy/haproxy.cfg
sudo yum install haproxy
cp haproxy.reload.path /etc/systemd/system/
cp haproxy.reload.service /etc/systemd/system/
sudo systemctl start haproxy.reload.path
sudo systemctl start haproxy.reload.service
sudo systemctl daemon-reload

 sudo kubeadm init --control-plane-endpoint "192.168.121.218:6443" --upload-certs --ignore-preflight-errors=all -v 5

kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml

kubectl create configmap ha-config --from-file=haproxy.cfg

kubectl apply -f sidecar-r-kubeconfigmap.yaml


