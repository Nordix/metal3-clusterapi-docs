## Vagrant test env for LB-HAProxy, 3 masters

* run
```sh
vagrant up
```

* install k8s binaries, upload cfg and yaml files etc
```sh
./run_me.sh
```
* on master1, create daemonsets and service
```sh
kubectl create configmap ha-servers-config --from-file=haproxy.cfg
kubectl apply -f hapxy-ok-ds.yaml
```
* run "backend servers" on master nodes
```sh
[vagrant@master1 ~]$ while true ; do nc -l -p 8888 -c 'echo -e "HTTP/1.1 200 OK\n\n $(date) MASTER1"'; done
[vagrant@master2 ~]$ while true ; do nc -l -p 8888 -c 'echo -e "HTTP/1.1 200 OK\n\n $(date) MASTER2"'; done
[vagrant@master3 ~]$ while true ; do nc -l -p 8888 -c 'echo -e "HTTP/1.1 200 OK\n\n $(date) MASTER3"'; done
```
* testing
```sh
cat config.txt
curl <master1 IP>:8888
curl <master1 IP>:31222
```
## misc:
* after haproxy.cfg change, reboot daemonset
```sh
kubectl delete pod PODNAME --grace-period=0 --force --namespace=default
```
* cfg checking on nodes
```sh
cat config.txt
[vagrant@master1 ~]$ vi /tmp/haproxy.cfg
[vagrant@master2 ~]$ vi /tmp/haproxy.cfg
[vagrant@master3 ~]$ vi /tmp/haproxy.cfg
```
* reload hapxy process, alternative for pod delete
```sh
[vagrant@master1 ~]$ kubectl exec -it ha-containers-???? -c haproxy-container /bin/bash
root@ha-containers:/# /usr/local/sbin/haproxy -f  /usr/local/etc/haproxy/haproxy.cfg -p /var/run/haproxy.pid -sf $(cat /var/run/haproxy.pid)
```
* logs
```sh
kubectl get pods -owide
kubectl describe pods <pod>

sudo docker logs  <Container ID>
e.g
sudo docker logs 95fe676b8de2b91356ce00569c999d16a451fcc41351c85f78534e6d38785929
```

