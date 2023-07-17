# Metal3 Scalability with Fake Nodes and Multiple Ironics

This directory stores the code and configuration for the __Metal3 Scalability with
Fake Nodes and Multiple Ironics__. Its purpose is to have a way of testing
[Metal3](https://metal3.io/) provisioning on multiple nodes, without needing
too much hardware resources.

## Requirements

To perform this experiment, you will need:

- A fresh Ubuntu machine with passwordless sudo.
- `docker` is installed and can be run without sudo.

## Quick Start

- Install some additional tools, add libvirt network
(named `baremetal`) by using `./vm-setup.sh`.
- Edit the [config.sh](config.sh) file with suitable configuration. We recommend
starting with small amount of nodes and clusters, just so you know the
setup works. Provisioning large numbers of nodes (500-1000) was tested
and worked well, but that will require large machine and longer time to proceed.
- Run the whole process with `./Init-environment.sh`

For easy comparison, here is the spec of the machine we used to provision 1000
single-node clusters:

- CPUs: 20 cores
- RAM: 64Gb
- Hard disk: 750Gb

The whole process took around 48h to finish.

## More detailed explanation

In this part, we will explain the purpose of steps taken in `Init-environment.sh`:

- `start_image_server.sh`: starts a nginx server running locally on port 8080. This
server will be used to store the images that ironic uses for provisioning the nodes.
- `minikube-setup.sh`: This sets up minikube with the configured amounts of CPUs
and Memory; then attachs the `baremetal` libvirt network to it.
- `run-ipa-downloader.sh`: This runs the `ipa-downloader` and gets an ipa image to
the image server. Since we use fake nodes, what images to use do not matter,
hence step is not crucial.
- `handle-images.sh`: This script downloads container images and inject into the
minikube VM. Might help speed up the process a little, if we run this setup
multiple times.
- `install-fkas`: This script installs [Metal3-FKAS](https://github.com/metal3-io/cluster-api-provider-metal3/tree/main/hack/fake-apiserver)
Deployment with the number of replicas specified in `config.sh`.
Metal3-Fkas will be responsible of generating API servers
and other kubernetes components for the newly provisioned clusters.
- `install-ironic`: This script helps installing ironic with the specified number
of `ironic-conductors`.
- `install-bmo`: This script installs [Baremetal Operator](https://book.metal3.io/bmo/introduction),
or BMO for short.
- `generate_unique_nodes.sh`: This script helps generating the configuration of
the fake nodes.
- `create-bmhs.py`: This script generate the BMH manifests based on the fake nodes
configuration.
- `start_containers.sh`: This script starts up `sushy-tools` and `fake-ipa` containers.
Each of them has the number of replicas as specified in `N_FAKE_IPAS` in the config.
- `apply-bmhs.sh`: This script applies all the BMH manifests into `metal3` namespace.
After this step, you should be able to see that all the BMHs exist and eventually
change their states to `available`. Note that the workload clusters will be in the
same namespace as the BMH objects, so if you want your clusters to be in another
namespace, you need to change this step.
- `clusterctl-init.sh`: This script only runs normal `clusterctl init` with `metal3`
as the infra provider. The result of this step is that we will have CAPI, CAPM3
and IPAM installed in the bootstrap cluster.
- `create-clusters.sh`: This step generate the new clusters. The number of clusters,
as well as how many CP and worker nodes they have, is in the config, too.

## Cleanup

Running `./clean.sh` should help removing most of what created by `Init-environment.sh`
