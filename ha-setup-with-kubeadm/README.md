### Setup a Kubernetes (k8s) Cluster in HA with Kubeadm

In this document we will demonstrate how to setup a Kubernetes(k8s) cluster
in HA (High Availability) with kubeadm utility [1]. For that we used 3 machines with
following details:

* ha-main-prow - Ubuntu 20.04 base image - 10.100.10.113 - 8GB RAM, 8vCPU, 50 GB
  Disk
* ha-backup-1-prow - Ubuntu 20.04 base image - 10.100.10.99 - 8GB RAM, 8vCPU, 50
  GB Disk
* ha-backup-2-prow - Ubuntu 20.04 base image - 10.100.10.123 - 8GB RAM, 8vCPU, 50
  GB Disk.

**Note:** the whole intention of this work was to setup a HA cluster to be used
for configuring a Prow setup on top, so the names for VMs have been chosen
accordingly. 

Set hostname and add entries in /etc/hosts file in each node, example is shown
for ha-main-prow node below:

```sh
hostnamectl set-hostname "ha-main-prow"
exec bash

```

Run above command on remaining nodes and set their respective hostnames. Once
hostname is set on all nodes, then add the following entries in /etc/hosts file
on all the nodes.

```sh
10.100.10.113  ha-main-prow
10.100.10.99   ha-backup-1-prow
10.100.10.123  ha-backup-2-prow
10.100.10.202  vip-k8s-main

```

We used one additional entry “10.100.10.202” for VIP (virtual IP) address in host
file because we will be using this IP and hostname while configuring the haproxy
and keepalived on all nodes.

Install keepalived and haproxy on each node:

```sh
sudo apt-get update
sudo apt install haproxy keepalived -y

```

Follow the below steps only on ha-main-prow node first.

#### **Step 1.** Configure keepalived

Take the backup of keepalived.conf file and then truncate the file.

```sh
sudo cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf-org
sudo sh -c '> /etc/keepalived/keepalived.conf'

```

Create keepalived configuration file:

```sh
ubuntu@ha-main-prow:~$ sudo vi /etc/keepalived/keepalived.conf

! Configuration File for keepalived
global_defs {
    notification_email {
    sysadmin@example.com
    support@example.com
    }
    notification_email_from lb@example.com
    smtp_server localhost
    smtp_connect_timeout 30
}
vrrp_instance VI_1 {
    state MASTER
    interface ens3
    virtual_router_id 1
    priority 101
    advert_int 1
    virtual_ipaddress {
        10.100.10.202
    }
}

```

**Note:** Only two parameters of this file need to be changed for backup-1 &
backup-2 nodes. __State__ will become __BACKUP__ for backup-1 & backup-2,
__priority__ will be __254__ & __253__ respectively. Also please pay close
attention to __interface__ parameter and set it accordingly to your environment.

#### **Step 2.** Configure haproxy

Configure HAProxy on ha-main-prow node and edit its configuration file:

```sh
ubuntu@ha-main-prow:~$ sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg-org

```

Remove all lines after default section and add following lines:

```sh
ubuntu@ha-main-prow:~$ sudo vim /etc/haproxy/haproxy.cfg

#---------------------------------------------------------------------
# apiserver frontend which proxys to the masters
#---------------------------------------------------------------------
frontend apiserver
    bind *:8443
    mode tcp
    option tcplog
    default_backend apiserver
#---------------------------------------------------------------------
# round robin balancing for apiserver
#---------------------------------------------------------------------
backend apiserver
    option httpchk GET /healthz
    http-check expect status 200
    mode tcp
    option ssl-hello-chk
    balance     roundrobin
        server ha-main-prow 10.100.10.113:6443 check
        server ha-backup-1-prow 10.100.10.99:6443 check
        server ha-backup-2-prow 10.100.10.123:6443 check

```

Now, repeat step 1 and step 2 on other nodes (ha-backup-1-prow & ha-backup-2-prow)
to configure keepalived/haproxy.
**Note:** Don't forget to change two parameters in keepalived.conf file we
discussed above for ha-backup-1-prow & ha-backup-2-prow.

In case firewall is running on nodes, add the following firewall rules on all
three nodes:

```sh
sudo firewall-cmd --add-rich-rule='rule protocol value="vrrp" accept' --permanent
sudo firewall-cmd --permanent --add-port=8443/tcp
sudo firewall-cmd --reload

```

Verify whether VIP is enabled on ha-main-prow node because we have marked
ha-main-prow as MASTER node in keepalived configuration file.

> ![VIP](VIP.png?raw=true)

Above output confirms that VIP has been enabled on ha-main-prow node. To verify
if keepalived configuration working properly, ping VIP address from
ha-backup-1-prow & ha-backup-2-prow and it should be successfull. Also check if
stopping keepalived on ha-main-prow with:

```sh
sudo systemctl stop keepalived

```

should result in moving of VIP address to ha-backup-1-prow, since it has higher
priority than ha-backup-2-prow. You can check VIP address output with the same
command above.

#### **Step 3.** Disable Swap, set SELinux as permissive and firewall rules

Disable Swap Space, set SELinux as Permissive on all the nodes with the following
commands:

```sh
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

```

In case firewall is running, allow the following ports on all nodes:

```sh
sudo apt install firewalld -y
sudo firewall-cmd --permanent --add-port=6443/tcp
sudo firewall-cmd --permanent --add-port=2379-2380/tcp
sudo firewall-cmd --permanent --add-port=10250/tcp
sudo firewall-cmd --permanent --add-port=10251/tcp
sudo firewall-cmd --permanent --add-port=10252/tcp
sudo firewall-cmd --permanent --add-port=179/tcp
sudo firewall-cmd --permanent --add-port=4789/udp
sudo firewall-cmd --reload
sudo modprobe br_netfilter
sudo sh -c "echo '1' > /proc/sys/net/bridge/bridge-nf-call-iptables"
sudo sh -c "echo '1' > /proc/sys/net/ipv4/ip_forward"

```

#### **Step 4.**  Install Container Runtime (CRI) Docker on nodes

Install Docker (Container Runtime) and enable it on all the nodes with following
commands:

```sh
sudo apt-get update
sudo apt install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable"
sudo apt install docker-ce docker-ce-cli containerd.io
sudo systemctl status docker
sudo systemctl enable docker --now

```

#### **Step 5.**  Install Kubeadm, kubelet and kubectl

Install kubeadm, kubelet and kubectl and enable kubelet on all nodes:

```sh
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
https://apt.kubernetes.io/ kubernetes-xenial main" \
| sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo systemctl enable kubelet --now

```

#### **Step 6.**  Initialize the Kubernetes Cluster

By default Kubeadm will create a config with cgroupDriver set to systemd. There
is a bug in Kubeadm version v1.22.1 where Kubelet fails with
[cgroup driver misconfiguration error](https://github.com/kubernetes/kubernetes/issues/43805)
at the time of writing. As a workaround, setting cgroupDriver to cgroupfs was
[suggested](https://github.com/kubernetes/kubernetes/issues/43805#issuecomment-907734385)
which would meet our needs. Create custom kubeadm config file with following
contents and save it as `kubeadm-config.yaml` only on ha-main-prow node, which we will use later:

```yaml
apiVersion: kubeadm.k8s.io/v1beta3
kind: ClusterConfiguration
kubernetesVersion: stable
controlPlaneEndpoint: "10.100.10.202:6443"
apiServer:
  extraArgs:
    advertise-address: 10.100.10.113
---
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 0s
    enabled: true
  x509:
    clientCAFile: /etc/kubernetes/pki/ca.crt
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 0s
    cacheUnauthorizedTTL: 0s
cgroupDriver: cgroupfs
kind: KubeletConfiguration

```

**Note:** Make sure, __controlPlaneEndpoint__ field from above yaml config
matches the VIP address you chose at the beginning.

Now, on ha-main-prow node, run the following command:

```sh
ubuntu@ha-main-prow:~$ sudo kubeadm init --upload-certs --config kubeadm-config.yaml

```

Output would be something like below:

> ![Kubeadm init output](kubeadm-init-output.png?raw=true)

Above output confirms that Kubernetes cluster has been initialized successfully.
Now, run following commands to allow local user to use kubectl command to
interact with cluster:

```sh
ubuntu@ha-main-prow:~$ mkdir -p $HOME/.kube
ubuntu@ha-main-prow:~$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
ubuntu@ha-main-prow:~$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
ubuntu@ha-main-prow:~$ cd /usr/bin/
ubuntu@ha-main-prow:~$ sudo chown ${USER}:${USER} kubectl
ubuntu@ha-main-prow:~$ cd /etc/kubernetes/
ubuntu@ha-main-prow:~$ sudo chown ${USER}:${USER} admin.conf

```

Deploy pod network (CNI – Container Network Interface), in our case we are going
to deploy calico addon as pod network:

```sh
ubuntu@ha-main-prow:~$ kubectl apply -f https://docs.projectcalico.org/v3.18/manifests/calico.yaml

```

Once the pod network is deployed successfully, add remaining two nodes
(ha-backup-1-prow & ha-backup-2-prow) to the cluster. To do that, copy the
command for ha-main-prow node to join the cluster from the output and paste it on
ha-backup-1-prow and ha-backup-2-prow, as below:

```sh
ubuntu@ha-backup-1-prow:~$ kubeadm join 10.100.10.202:6443 \
--token pjwl6m.r4iymxt1mtcl27mb --discovery-token-ca-cert-hash \
sha256:29215c9447f82c9f1491c604ae45b491c8b93adb0f5adca8a275c1bba201bbda \
--control-plane --certificate-key \
405a6e0b16783a525695ef2b11f4ceafb30158b894b9597a05eb81ac250afa48

```

and

```sh
ubuntu@ha-backup-2-prow:~$ kubeadm join 10.100.10.202:6443 \
--token pjwl6m.r4iymxt1mtcl27mb --discovery-token-ca-cert-hash \
sha256:29215c9447f82c9f1491c604ae45b491c8b93adb0f5adca8a275c1bba201bbda \
--control-plane --certificate-key \
405a6e0b16783a525695ef2b11f4ceafb30158b894b9597a05eb81ac250afa48

```

Output would be:

> ![Kubeadm join output](kubeadm-join-output.png?raw=true)

Above output confirms that ha-backup-1-prow node has also joined the cluster
successfully. Last, let's verify the nodes status from kubectl command, for that,
go to ha-main-prow node and execute below command:

> ![All nodes output](nodes-output.png?raw=true)

Perfect, all our three control plane nodes are ready and joined the cluster
successfully. Now we can deploy Prow on top of the existing cluster.

**Note**: While deploying Prow on the environment configured following the above
steps, we have seen some Prow specific pods (i.e deck and hook) not being able to
run properly in the cluster, whereas same pods do run without any errors in a
single master environment. For that reason, further investigations might be
needed to find out the root cause of the problem and in order to be able to
deploy Prow setup in HA k8s cluster.

#### References:

[1] https://www.linuxtechi.com/setup-highly-available-kubernetes-cluster-kubeadm/