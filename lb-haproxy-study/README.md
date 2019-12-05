# Configure HAProxy on control plane as a daemon set on top of Kubernetes or as a service on plain Linux

## Results, findings and workflows shall be documented in this README

## HAPROXY as daemonset or service
* HAProxy options, assumption for all options is that needed **cloud-init** can be created from userdata given in Kubernetes CRs

### Tasks:
#### General
* Check how iptables setting works
  'Done, outcome here'
* Check how nc or etc. tunneling configuration works
  'Done, outcome here'

#### HAProxy running outside a cluster as an external service
HAProxy and update logic services are started in 'cloud-init' phase before kubeadm init/join.
HAProxy config has to contain port mapping from port used in 'kubeam --control-plane-endpoint' parameter to API server port.
No need for iptables or socat tunneling for port forwarding from LB port to API server port.

* HAProxy config update logic service runs as an external service reading configmap content using access token. Token is generated in cloud init phase after kubeadm init and serviceaccount creation is made. This account gives rights to read configmaps. Token can be exposed to config update process as environment variable.
  * HAProxy update logic periodically reads the status of configmap and if configmap is changed, it will update master node IP addresses /etc/haproxy/haproxy.cfg and then restarts HAProxy with systemctl command.

#### HAProxy as a daemonset
* Iptables or socat tunneling for port forwarding needed from LB port to API server port, this need to be activated in 'cloud-init' before kubeadm init
* After port forwarding is activated 'kubeadm init' can be run with option '--control-plane-endpoint' 'LB port'

* HAProxy and sidecar option:
  * After cluster is up, HAProxy with config update sidecar pod is created. Sidecar container uses serviceaccount token to periodically poll configmap status from API server
  * Sidecar and HAProxy containers share the same volume so that sidecar can update HAProxy config directly to '/etc/haproxy/haproxy.cfg'
  * Sidecar periodically reads the status of configmap and if configmap is changed, it will update master node IP addresses '/etc/haproxy/haproxy.cfg' and then exec to HAProxy container and restarts HAProxy process with systemctl command

* HAProxy reads configmap which is mounted as a volume
  * A delay (~60 sec) is identified when configmap is modified until the HAProxy sees the change, not seen as an issue at least for now 

#### Visualization
[Draw.io](https://www.draw.io/#G15Fv5MDyr7YOiKmU_-e-ABYpOs6ZJnBu1)

### Open issues:
* How to sync HAProxy daemonset pod starting and IP forward rule deactivation?
* Can you add deployment(pod etc,) contend to kubeadm init config yaml? 

        
### Test environments:
* Metal3-dev-env, primary test env, iterations take time
* Vagrant nodes, no applicable environment available now. Trial done with [Vagrant-cloud-init](https://github.com/craighurley/vagrant-cloud-init.git). Additional effort needed to get it working. Testing modified cloud-init is problematic


