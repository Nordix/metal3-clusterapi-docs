# Configure HAProxy on control plane as a daemon set on top of Kubernetes or as a service on plain Linux

## Results, findings and workflows shall be documented in this README

## HAPROXY as daemonset or service

* HAProxy options, assumption for all options is that needed `cloud-init` can be created from userdata given in Kubernetes CRs

### Tasks

#### General

* Check how iptables setting works
  * 'Done, outcome here'
* Check how nc or etc. tunneling configuration works
  * 'Done, outcome here'

#### HAProxy running outside a cluster as an external service

HAProxy and update logic services are started in `cloud-init` phase before kubeadm init/join.
HAProxy config has to contain port mapping from port used in `kubeam --control-plane-endpoint` parameter to API server port.
No need for iptables or socat tunneling for port forwarding from LB port to API server port.

* Option1 Periodical polling of configmap with token
  * HAProxy config update logic service runs as an external service reading configmap content using access token. Token is generated in cloud init phase after kubeadm init and serviceaccount creation is made. This account gives rights to read configmaps. Token can be exposed to config update process as environment variable.
  * HAProxy update logic periodically reads the status of configmap and if configmap is changed, it will update master node IP addresses `/etc/haproxy/haproxy.cfg` and then restarts HAProxy with systemctl command.

* Option2 Configmap mounted as host volume
  * Configmap is mounted as host volume into haproxy.cfg file so that haproxy can use that as is when soft link created between mounted haproxy.cfg and config location haproxy uses in restart
  * systemctl path unit used to detect changes in mounter haproxy.cfg and trigger service restarting haproxy in case changes occur.
  * Haproxy has internal logic to do restart gracefully.

#### HAProxy as a daemonset

* IPtables or socat tunneling for port forwarding needed from LB port to API server port, this need to be activated in `cloud-init` before kubeadm init
* After port forwarding is activated `kubeadm init` can be run with option `--control-plane-endpoint LB port`

* Option1, HAProxy and sidecar:
  * After cluster is up, HAProxy with config update sidecar pod is created. Sidecar container uses serviceaccount token to periodically poll configmap status from API server
  * Sidecar and HAProxy containers share the same volume so that sidecar can update HAProxy config directly to `/etc/haproxy/haproxy.cfg`
  * Sidecar periodically reads the status of configmap and if configmap is changed, it will update master node IP addresses `/etc/haproxy/haproxy.cfg` and then exec to HAProxy container and restarts HAProxy process with systemctl command
  * Sidecar and HAProxy can use 'shareProcessNamespace:true' and thus Sidecar can reboot HAProxy by killing its process
  * Alternatively a daemonset pod could be deleted to force cfg-file reading but this would require kubectl and is not preferred due to security reasons
  * Test environment can be found in `LB-HAProxy-ds-sc` directory
  * Port mapping from nodePort to API server can be do with socat
    before mapping deployed inside crluster: `sudo socat tcp-l:31117,fork,reuseaddr tcp:127.0.0.1:6443`
* Option2, HAProxy reads configmap which is mounted as a volume
  * A delay (~60 sec) is identified when configmap is modified until the HAProxy sees the change, not seen as an issue at least for now

* Option3, run an initial Load balancer (here HAProxy) on ephemeral cluster - a proposal from CAPI developer meeting
  * LB with port forwarding (e.g port `1234` -> `master-0-IP:6443`) is created in ephemeral cluster cloud-init phase (or deploy to ephemeral cluster?). Ephemeral cluster has keepalived owning VIP. Target cluster master-0 kubeadm init created with kubeconfig having access IP VIP:1234, then daemonset LB with port `1234` -> `mastersIP[]:6443` mapping created. Finally keepalived can be deactivated from ephemeral cluster
  * keepalived takes care of the switch from ephemeral to target node/cluster

#### Visualization

[Draw.io](https://www.draw.io/#G15Fv5MDyr7YOiKmU_-e-ABYpOs6ZJnBu1)

### Open issues

* Can you add deployment(pod etc,) contend to kubeadm init config yaml?

### Test environments

* Metal3-dev-env, primary test env, iterations take time
* Cloud-init testing in Vagrant nodes, no applicable environment available now
  * Trial done with [Vagrant-cloud-init](https://github.com/craighurley/vagrant-cloud-init.git). Additional effort needed to get it working. Testing modified cloud-init is problematic
* Option1: LB-HAProxy-ds-sc directory
