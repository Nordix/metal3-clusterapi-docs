# Introduction

In this development environment, deploying kubernetes involves two steps.

- Create machines with required binaries, such as kubelete, kubeadm and docker
- Create a kubernetes cluster using tools such as kubeadm

The scripts under `./providers/kinder/` provide the solution to both of
the above tasks as follows:

**Creating Machines**: Using the scripts under `/providers/kinder/`, it
is possible to create machines with relevant binaries. The versions of
the variables is determined by the node-image built using kinder.

As to networking, each control plane node has multiple control plane
networks and workers are connected to multiple traffic networks.
Experiments related to workers networking can be ignored for now. When
it is considered again, we would like to separate the control plane
networks and traffic networks and experiments need to be done on that.

**Creating K8s cluster:** The creation of the K8s cluster is a manual
process and needs to be done as described below.

A kubernetes control plane is made of multiple components, such as the
API server, etcd and scheduler. The components that are of interest to
us at this point are the API server and the etcd database.

## Experiments overview

The main focus on studying the behavior of kubeadm when run on a machine
with multiple interfaces. And, We try to answer the following questions.

- How do these components choose which interfaces to use ?
- How do we influence the choice during init phase ?
- How do we influence the choice during join phase ?
- How granular the configuration could be made.

As shown below, there are multiple traffic networks for the workers and
additional control plane networks. Although different kinds of tests can
be done, we focus on the extreme case in that:

- etcd to etcd communication done over an etcd-network
- api-server to api-server communication done over an api-network (with
  or without a load balancer)
- api-server to etcd communication over localhost if they are on the same machine
- api-server to etcd communication not possible if they are on separate machines

Alternative topologies can be found
[here](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/)

## Kinder based machine creation

### prerequisites

- [Kinder](https://github.com/kubernetes/kubeadm/tree/master/kinder) and
  [jq](https://stedolan.github.io/jq/download/) are installed
- None of the networks defined in `./setup_test_environment.sh` conflict
  with existing docker networks
- No cluster exists with the same name or else it will delete and
  re-create it

### Setup test environment

```bash
./providers/kinder/setup_test_environment.sh <cluster name> \
    [<number of controlplanes> <number of workers> <kindest node version>]
```

If you do not provide the number of workers or controlplanes or both,
then both default to 3. Kindest node version is by default
**kindest/node:v1.18.0**

### Teardown test environment

```bash
./providers/kinder/teardown_test_environment.sh <cluster name>
```

## Motivation

For this experiment our motivation is to know the answers of the following questions

- How do these components choose which interfaces to use?
- How do we influence the choice during init phase?
- How do we influence the choice during join phase?
- How granular the configuration could be made?

## Requirements

In a multi interface control plane node, configuring control plane such that

- IP addresses of control plane components are pre-determined
- During init phase, control plane components use distinct IP addresses
- During join phase, control plane components use distinct IP addresses

## Test Cases

- Apply **kubeadm** init and join with default configurations to check
  how it populates the different static pod manifest files
- Use a custom **kubeadm-init** config file where we add only
  **api-server** related configurations and check if a different
  interface for **api-server** is assigned
- Extend the 2nd test case by adding **etcd-server** related
  configurations in **kubeadm-init** config file and check if different
  interfaces for **api-server**  and **etcd-server** gets assigned.
- In all of the above cases, consider the impact of these configurations
  using **kubeadm-join** config file.

## Test Results

**Test case 1:**

- Setup: No custom kubeconfig-init nor kubeconfig-join provided
- Desired result: None
- Actual Result: Both etcd and api-server get the default IP
- Observation: None

**Test case 2:**

- Setup: Custom kubeconfig-init with only api-server given a non-default IP
- Desired result: Both api-server and etcd use the given IP
- Actual Result: As expected
- Observation: On the joining node, the default IP was used for both
  etcd and api-server, i.e. The IP in the joining string did not
  contribute in IP selection.

**Test case 3:**

- Setup: Custom kubeconfig-init and kubeconfig-join with etcd on IP1 and
  api-server on IP2 where both IP1 and IP2 are non-default
- Desired result: api-server and etcd use their respective IPs
- Actual Result: As expected
- Observation: On the joining node, the default IP was used for both
  etcd and api-server, i.e. The IP in the joining string did not
  contribute in IP selection.

**Test case 4:**

- Setup: Custom kubeconfig-init with etcd on master1 has IP1 and
  api-server on master 1 has IP2 where both IP1 and IP2 are non-default.
  The kubeconfig-join configures api-server in master 2 to use its own
  non-default IP3 and points to the api-server IP1 in master 1 as the
  **K8S_API_ENDPOINT_INTERNAL** (The config files are attache in later
  sections)
- Desired result: The api-server and etcd in master 1 and api-server in
  master 2 use the given IP
- Actual Result: As expected
- Observation: On the joining node, the given IP was used for
  api-server, i.e. The joining configuration file has an influence in IP
  selection.

## Observations

Here we just pinpoint the answers for the questions asked in
[Motivation](#motivation) section:

How do these components choose which interfaces to use?

- They use the interface on default network.

How do we influence the choice during init phase?

- Using kubeadm-init config file

How do we influence the choice during join phase?

- Using kubeadm-join config file

How granular the configuration could be made?

- Only the case where the api server and the etcd use the SAME none defautl ip works
- Making them use separate interfaces (IPs) was not succeeding on the joining end.

## kubeadm-init config file sample

```yml
    apiVersion: kubeadm.k8s.io/v1beta2
    kind: InitConfiguration
    localAPIEndpoint:
    advertiseAddress: 192.168.10.2
    bindPort: 6443
    nodeRegistration:
    criSocket: /var/run/dockershim.sock
    name: mycluster1-control-plane
    taints:
    - effect: NoSchedule
        key: node-role.kubernetes.io/master
    ---
    apiServer:
    timeoutForControlPlane: 60s
    controlPlaneEndpoint: 192.168.10.2:6443
    apiVersion: kubeadm.k8s.io/v1beta2
    certificatesDir: /etc/kubernetes/pki
    clusterName: kubernetes
    controllerManager: {}
    dns:
    type: CoreDNS
    #etcd:
    #  local:
    #    dataDir: /var/lib/etcd
    #    extraArgs:
    #      initial-cluster-state: new
    #      name: mycluster1-control-plane
    #      initial-cluster: mycluster1-control-plane=https://192.168.10.2:2380
    #      initial-advertise-peer-urls: https://192.168.10.2:2380
    #      listen-peer-urls: https://192.168.10.2:2380
    #      advertise-client-urls: https://127.0.0.1:2379,https://192.168.10.2:2379
    #      listen-client-urls: https://127.0.0.1:2379,https://192.168.10.2:2379
    imageRepository: k8s.gcr.io
    kind: ClusterConfiguration
    kubernetesVersion: v1.15.1
    networking:
    dnsDomain: cluster.local
    serviceSubnet: 10.96.0.0/12
    scheduler: {}
```

## kubeadm-join config file sample

```bash
    #!/bin/bash
    ​
    echo "--- Joining Cluster "
    KUBEADM_CONF=/root/kubeadm-join-config.conf
    K8S_API_ENDPOINT_INTERNAL="192.168.10.2:6443"
    KUBEADM_TOKEN="285yyn.cxknw9qaipi792fe"
    CA_CERT_HASH="sha256:8925cf33db5bc7cd2c960d82231211601c3841f93a0f2c0e3794395e2a4c6f47"
    CERT_KEY="a60bfc726ed405c6fb457220e1486855a50ff107b70ce9a9bc8b170ffcc5ddba"
    ​
    ​
    rm ${KUBEADM_CONF}
    cat <<EOF >${KUBEADM_CONF}
    apiVersion: kubeadm.k8s.io/v1beta2
    kind: JoinConfiguration
    nodeRegistration:
    kubeletExtraArgs:
        node-labels: "node-type=rook"
    discovery:
    bootstrapToken:
        apiServerEndpoint: ${K8S_API_ENDPOINT_INTERNAL}
        token: ${KUBEADM_TOKEN}
        unsafeSkipCAVerification: true
        caCertHashes:
        - ${CA_CERT_HASH}
    tlsBootstrapToken: ${KUBEADM_TOKEN}
    ​
    controlPlane:
    certificateKey: ${CERT_KEY}
    localAPIEndpoint:
        advertiseAddress: 192.168.10.3
    EOF
    ​
    ​
    kubeadm reset -f
    #cp -r /tmp/pki/* /etc/kubernetes/pki/
    kubeadm join --config ${KUBEADM_CONF} --ignore-preflight-errors=all
​
```

## Useful script for setting alias

```bash
    #!/bin/bash
    alias showconfigmap="kubectl -n kube-system get cm kubeadm-config -oyaml"
    alias listfiles="tree /etc/kubernetes/manifests"
    alias showetcd="more /etc/kubernetes/manifests/etcd.yaml"
    alias showapi="more /etc/kubernetes/manifests/kube-apiserver.yaml"
```
