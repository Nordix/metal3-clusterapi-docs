# n+3 upgrade POC

The goal of this POC is to observe the feasibility of doing n+3 upgrade process for kubernetes versions. Our requirements were to upgrade control plane node in three following k8s minor version  for each k8s release and keep the worker behind in n-3 verison at the end of the test. Theoritically it was possible but here we were testing it locally to see the practical situation during upgrade. Each and every upgrade in this POC was given enough time to observe and report any unusual behavior of the cluster. At the end of the test our cluster should looks like the following

```sh
kubectl get nodes

NAME                 STATUS   ROLES           VERSION
kind-control-plane   Ready    control-plane   v1.(n+3).*
kind-worker          Ready    <none>          v1.(n).*
```

## High level view of the upgrade process

We started our test cluster was having 1.30 kubernetes version and will do the upgrade of the k8s version one by one.

Steps to follow in each upgrade of k8s version

1. Start upgrading from controlplane
1. Update or replace new repository for k8s and download keyrings for expected k8s version
1. Update package list
1. Upgrade kubeadm and apply it to controlplane
1. Upgrade kubelet and Kubectl. Reload daemon and restart kubelet.

## Upgrade k8s from 1.30 to 1.31

1. First step of upgrading will begin from the controlplane node.

```sh
docker exec -it kind-control-plane /bin/bash

```

First step is to update/replace the new repository instead of the Google-hosted repository.
Make sure to replace the Kubernetes minor version in the command below with the minor version that you're currently using

```sh
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
```

After that download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories, so you can disregard the version in the URL

```sh
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

**note In releases older than Debian 12 and Ubuntu 22.04, the folder /etc/apt/keyrings does not exist by default, and it should be created before the curl command.

Update the apt package index:

```sh
apt-get update
```

1. Check for possible kubeadm packages for upgrade

```sh
$ apt-cache madison kubeadm

   kubeadm | 1.30.13-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb Packages
   kubeadm | 1.30.12-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb Packages
   kubeadm | 1.30.11-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb Packages
   kubeadm | 1.30.10-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb Packages
   kubeadm | 1.30.9-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.8-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.7-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.6-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.5-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
   kubeadm | 1.30.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.30/deb  Packages
```

1. Upgrade kubeadm to required version

```sh
apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm=1.31.10-1.1 && apt-mark hold kubeadm
```

```sh
$ kubeadm version

kubeadm version: &version.Info{Major:"1", Minor:"31", GitVersion:"v1.31.10", GitCommit:"61183587c03f420214aac57f81dc0ecb43e1b0d6", GitTreeState:"clean", BuildDate:"2025-06-17T18:39:10Z", GoVersion:"go1.23.10", Compiler:"gc", Platform:"linux/amd64"}
```

1. Run the kubeadm upgrade plan to see possibe version to upgrade

```sh
$ kubeadm upgrade plan

[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the cluster...
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: 1.30.13
[upgrade/versions] kubeadm version: v1.31.10
[upgrade/versions] Target version: v1.31.10
[upgrade/versions] Latest version in the v1.30 series: v1.30.14

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':

COMPONENT   NODE                 CURRENT    TARGET
kubelet     kind-control-plane   v1.30.13   v1.30.14
kubelet     kind-worker          v1.30.13   v1.30.14

Upgrade to the latest version in the v1.30 series:

COMPONENT                 NODE                 CURRENT    TARGET
kube-apiserver            kind-control-plane   v1.30.13   v1.30.14
kube-controller-manager   kind-control-plane   v1.30.13   v1.30.14
kube-scheduler            kind-control-plane   v1.30.13   v1.30.14
kube-proxy                                     1.30.13    v1.30.14
CoreDNS                                        v1.11.3    v1.11.3
etcd                      kind-control-plane   3.5.15-0   3.5.15-0

You can now apply the upgrade by executing the following command:

kubeadm upgrade apply v1.30.14
_____________________________________________________________________

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   NODE                 CURRENT    TARGET
kubelet     kind-control-plane   v1.30.13   v1.31.10
kubelet     kind-worker          v1.30.13   v1.31.10

Upgrade to the latest stable version:

COMPONENT                 NODE                 CURRENT    TARGET
kube-apiserver            kind-control-plane   v1.30.13   v1.31.10
kube-controller-manager   kind-control-plane   v1.30.13   v1.31.10
kube-scheduler            kind-control-plane   v1.30.13   v1.31.10
kube-proxy                                     1.30.13    v1.31.10
CoreDNS                                        v1.11.3    v1.11.3
etcd                      kind-control-plane   3.5.15-0   3.5.15-0

You can now apply the upgrade by executing the following command:

kubeadm upgrade apply v1.31.10
_____________________________________________________________________

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________
```

1. Upgrade kubeadm with the expected k8s version

```sh
$ kubeadm upgrade apply v1.31.10
[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the cluster...
[upgrade/config] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
[upgrade] Running cluster health checks
[upgrade/version] You have chosen to change the cluster version to "v1.31.10"
[upgrade/versions] Cluster version: v1.30.13
[upgrade/versions] kubeadm version: v1.31.10
[upgrade] Are you sure you want to proceed? [y/N]: y
[upgrade/apply] Upgrading your Static Pod-hosted control plane to version "v1.31.10" (timeout: 5m0s)...
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade/successful] SUCCESS! Your cluster was upgraded to "v1.31.10". Enjoy!

[upgrade/kubelet] Now that your control plane is upgraded, please proceed with upgrading your kubelets if you haven't already done so.
```

1. Upgrade kubelet and kubectl

Open a new terminal (outside the docker exec) and mark the node unschedulable (cordon) and then evict the workload (drain)

```sh
$ kubectl drain kind-control-plane --ignore-daemonsets

$ kubectl get nodes
NAME                 STATUS                     ROLES           AGE   VERSION
kind-control-plane   Ready,SchedulingDisabled   control-plane   6d    v1.30.13
kind-worker          Ready                      <none>          6d    v1.30.13

# Now, come back to the former terminal with the docker exec (into control-plane node):

 $ apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet=1.31.10-1.1 kubectl=1.31.10-1.1 && apt-mark hold kubelet kubectl

 $ systemctl daemon-reload
 $ systemctl restart kubelet

# And now go back to the other terminal outside the docker exec, and uncordon the node:

$ kubectl uncordon kind-control-plane

$ kubectl get nodes -o wide
NAME                 STATUS   ROLES          VERSION    INTERNAL-IP     OS-IMAGE                         KERNEL-VERSION       CONTAINER-RUNTIME
kind-control-plane   Ready    control-plane  v1.31.10   172.18.0.3      Debian GNU/Linux 12 (bookworm)   5.15.0-102-generic   containerd://2.1.1
kind-worker          Ready    <none>         v1.30.13   172.18.0.2      Debian GNU/Linux 12 (bookworm)   5.15.0-102-generic   containerd://2.1.1


Upgrade to 1.30.13 to 1.31.10 was done successfull for controlplane
```

## Upgrade k8s version from 1.31 to 1.32

Similar steps descried in previous sectio will be followed here with new k8s version.

1. Replace the apt repository definition so that apt points to the new repository instead of the Google-hosted repository. Make sure to replace the Kubernetes minor version in the command below with the minor version that you're currently using

```sh
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
```

1. Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories, so you can disregard the version in the URL:

```sh
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

1. Update the apt package index:

```sh
$ apt-get update

$ apt-cache madison kubeadm
   kubeadm | 1.32.6-1.1 | https://pkgs.k8s.io/core:/stable:/v1.32/deb  Packages
   kubeadm | 1.32.5-1.1 | https://pkgs.k8s.io/core:/stable:/v1.32/deb  Packages
   kubeadm | 1.32.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.32/deb  Packages
   kubeadm | 1.32.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.32/deb  Packages
   kubeadm | 1.32.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.32/deb  Packages
   kubeadm | 1.32.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.32/deb  Packages
   kubeadm | 1.32.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.32/deb  Packages

# Install the kubeadm to 1.32.6-1.1

$ apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm=1.32.6-1.1 && apt-mark hold kubeadm

$ kubeadm upgrade plan
```

1. Apply kubeadm upgrade

```sh
$ kubeadm upgrade apply v1.32.6

[upgrade] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[upgrade] Use 'kubeadm init phase upload-config --config your-config.yaml' to re-upload it.
[upgrade/preflight] Running preflight checks
[upgrade] Running cluster health checks
[upgrade/preflight] You have chosen to upgrade the cluster version to "v1.32.6"
[upgrade/versions] Cluster version: v1.31.10
[upgrade/versions] kubeadm version: v1.32.6
[upgrade] Are you sure you want to proceed? [y/N]: y
[upgrade/control-plane] Upgrading your static Pod-hosted control plane to version "v1.32.6" (timeout: 5m0s)...
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.32.6".

[upgrade] Now please proceed with upgrading the rest of the nodes by following the right order.
```

1. Upgrade kubelet and Kubectl

```sh
Open a new terminal (outside the docker exec) and mark the node unschedulable (cordon) and then evict the workload (drain)

# Outside the docker exec terminal
$ kubectl drain kind-control-plane --ignore-daemonsets

#Now, come back to the former terminal with the docker exec (into control-plane node):

$ apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet=1.32.6-1.1 kubectl=1.32.6-1.1 && apt-mark hold kubelet kubectl

Canceled hold on kubelet.
Canceled hold on kubectl.
Reading package lists... Done
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following packages will be upgraded:
  kubectl kubelet
2 upgraded, 0 newly installed, 0 to remove and 8 not upgraded.
Preparing to unpack .../kubectl_1.32.6-1.1_amd64.deb ...
Setting up kubectl (1.32.6-1.1) ...
Setting up kubelet (1.32.6-1.1) ...
kubelet set on hold.
kubectl set on hold.

$ systemctl daemon-reload
$ systemctl restart kubelet

# And now go back to the other terminal outside the docker exec, and uncordon the node:

$ kubectl uncordon kind-control-plane

$ kubectl get nodes
NAME                 STATUS   ROLES           AGE     VERSION
kind-control-plane   Ready    control-plane   6d21h   v1.32.6
kind-worker          Ready    <none>          6d21h   v1.30.13
```

Upgrade to 1.32.6 was successfull

## Upgrade k8s version from 1.32 to 1.33

Same steps will be repeated for newest k8s upgrade version upgrade for controlplane

1. Replace the apt repository definition so that apt points to the new repository instead of the Google-hosted repository.
   Make sure to replace the Kubernetes minor version in the command below with the minor version that you're currently using

```sh
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list
```

1. Download the public signing key for the Kubernetes package repositories. The same signing key is used for all repositories, so you can disregard the version in the URL

```sh
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
```

1. Update the apt package index:

```sh
$ apt-get update
$ apt-cache madison kubeadm
   kubeadm | 1.33.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.33/deb  Packages
   kubeadm | 1.33.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.33/deb  Packages
   kubeadm | 1.33.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.33/deb  Packages

$ apt-mark unhold kubeadm && apt-get update && apt-get install -y kubeadm=1.33.2-1.1 && apt-mark hold kubeadm

$ kubeadm upgrade plan
[preflight] Running pre-flight checks.
[upgrade/config] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[upgrade/config] Use 'kubeadm init phase upload-config --config your-config-file' to re-upload it.
[upgrade] Running cluster health checks
[upgrade] Fetching available versions to upgrade to
[upgrade/versions] Cluster version: 1.32.6
[upgrade/versions] kubeadm version: v1.33.2
[upgrade/versions] Target version: v1.33.2
[upgrade/versions] Latest version in the v1.32 series: v1.32.6

Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
COMPONENT   NODE                 CURRENT    TARGET
kubelet     kind-worker          v1.30.13   v1.33.2
kubelet     kind-control-plane   v1.32.6    v1.33.2

Upgrade to the latest stable version:

COMPONENT                 NODE                 CURRENT    TARGET
kube-apiserver            kind-control-plane   v1.32.6    v1.33.2
kube-controller-manager   kind-control-plane   v1.32.6    v1.33.2
kube-scheduler            kind-control-plane   v1.32.6    v1.33.2
kube-proxy                                     1.32.6     v1.33.2
CoreDNS                                        v1.11.3    v1.12.0
etcd                      kind-control-plane   3.5.16-0   3.5.21-0

You can now apply the upgrade by executing the following command:

kubeadm upgrade apply v1.33.2
_____________________________________________________________________

API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
kubelet.config.k8s.io     v1beta1           v1beta1             no
_____________________________________________________________________

$ kubeadm upgrade apply v1.33.2
```

1. Issue in pre-flight check during kubeadm upgrade

```sh
# Encountered error in pre-flight check
$ kubeadm upgrade apply v1.33.2
[upgrade] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
[upgrade] Use 'kubeadm init phase upload-config --config your-config-file' to re-upload it.
[upgrade/preflight] Running preflight checks
[preflight] The system verification failed. Printing the output from the verification:
KERNEL_VERSION: 5.15.0-102-generic
OS: Linux
CGROUPS_CPU: enabled
CGROUPS_CPUSET: enabled
CGROUPS_DEVICES: enabled
CGROUPS_FREEZER: enabled
CGROUPS_MEMORY: enabled
CGROUPS_PIDS: enabled
CGROUPS_HUGETLB: enabled
CGROUPS_IO: enabled
error execution phase preflight: [preflight] Some fatal errors occurred:
[ERROR SystemVerification]: failed to parse kernel config: unable to load kernel module: "configs", output: "modprobe: FATAL: Module configs not found in directory /lib/modules/5.15.0-102-generic\n", err: exit status 1
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`

Issue: kernel module cannot be found
```

1. Pre flight test was failing because of the kernal module which can be bypassed by ignoring all errors. Which were not related to the k8s upgrade

```sh
$ kubeadm upgrade apply v1.33.2 --ignore-preflight-errors=all

[upgrade] Backing up kubelet config file to /etc/kubernetes/tmp/kubeadm-kubelet-config2115213502/config.yaml
[kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
[upgrade/kubelet-config] The kubelet configuration for this node was successfully upgraded!
[upgrade/bootstrap-token] Configuring bootstrap token and cluster-info RBAC rules
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to get nodes
[bootstrap-token] Configured RBAC rules to allow Node Bootstrap tokens to post CSRs in order for nodes to get long term certificate credentials
[bootstrap-token] Configured RBAC rules to allow the csrapprover controller automatically approve CSRs from a Node Bootstrap Token
[bootstrap-token] Configured RBAC rules to allow certificate rotation for all node client certificates in the cluster
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

[upgrade] SUCCESS! A control plane node of your cluster was upgraded to "v1.33.2".

# Outside the docker exec terminal
$ kubectl drain kind-control-plane --ignore-daemonsets

$ kubectl get nodes

# Now come back to the former terminal with the docker exec (into control-plane node):

$ apt-mark unhold kubelet kubectl && apt-get update && apt-get install -y kubelet=1.32.6-1.1 kubectl=1.33.2-1.1 && apt-mark hold kubelet kubectl

$ systemctl daemon-reload
$ systemctl restart kubelet

# And now go back to the other terminal outside the docker exec, and uncordon the node:

$ kubectl uncordon kind-control-plane

$ kubectl get nodes
NAME                 STATUS   ROLES           AGE   VERSION
kind-control-plane   Ready    control-plane   8d    v1.33.2
kind-worker          Ready    <none>          8d    v1.30.13

# Observed the cluster after each upgrade and all the pods were running and wasn't visible any issue

$ kubectl get pods -A
NAMESPACE            NAME                                         READY   STATUS    RESTARTS       AGE
kube-system          coredns-674b8bbfcf-hslkg                     1/1     Running   0              7m53s
kube-system          coredns-674b8bbfcf-scrrr                     1/1     Running   0              7m53s
kube-system          etcd-kind-control-plane                      1/1     Running   0              38s
kube-system          kindnet-cr4qp                                1/1     Running   0              8d
kube-system          kindnet-sm7zb                                1/1     Running   1              8d
kube-system          kube-apiserver-kind-control-plane            1/1     Running   0              38s
kube-system          kube-controller-manager-kind-control-plane   1/1     Running   0              38s
kube-system          kube-proxy-n2ln7                             1/1     Running   0              14m
kube-system          kube-proxy-nktth                             1/1     Running   0              14m
kube-system          kube-scheduler-kind-control-plane            1/1     Running   0              38s
local-path-storage   local-path-provisioner-7cbc4bc5cf-k5mn2      1/1     Running   0              2d1h
```

**Note** To save time and unneccesary encounter of bugs, I would recommend to avoid upgrading the zero patch release(such as 1.30.0, 1.31.0). It seems that there are possibility to have some kinds of bugs, which would be solved in stable versions in new patch release.
