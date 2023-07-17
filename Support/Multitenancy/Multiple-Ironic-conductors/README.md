# Multiple ironics setup

For a shorter summary of what this study is about, you can check out the `SUMMARY.md` file. This wall of text will try to explain everything in a more detailed manner.

## Purposes

- Following metal3-dev-env workflow, currently only one `ironic-conductor` could be installed in one cluster. Despite ironic being very good in handling parallel traffics, having only one of it means that we can only have so many nodes being provisioned and managed, until ironic stops accepting new connections (or new nodes). Being able to scale `ironic-conductor` is, therefore crucial to improve metal3 and BMO performance.
- Assuming that we could make multiple conductors scenario work, testing it would be an issue. A massive number (say, 1000) of machines, even virtual ones, is generally not something available for everyone. For that reason, we also introduce the new [ipa simulating tool](https://review.opendev.org/c/openstack/sushy-tools/+/875366), a.k.a `fake-ipa`, which allows simulating inspection and provision for multiple baremetal nodes, without the need of real hardwares. In a glance, the tool tries to handle all the traffics that would normally be handled by the `ironic python agent`s (notice the plural form), without needing to run inside real (or fake) machines. So, `ironic` would think it would be talking to multiple real ipas, instead of a single fake one.

## Steps

### Build the new container images

At the time of writing, the `fake-ipa` commit has not been merged to `sushy-tools` repo yet, so to kick start this setup, we need to build a custom sushy-tools image with `fake-ipa` change. That inclues cloning the repo, cherry-picking the commit, adding a Dockerfile, and building a new container image. All of these things are handled automatically with the script `build-sushy-tools-image.sh`, which you can find inside the same directory as this file.

```bash
./build-sushy-tools-image.sh
```

The result image will be tagged as `127.0.0.1:5000/localimages/sushy-tools`, and it will be used to run both `sushy-tools` and `fake-ipa` containers (with different entry points).

### Setup the host machine

In the next step, we want to setup some stuff in the host machine to prepare for the simulation. It includes installing needed packages, setting some new networks, firewalls, etc., and all are handled by the script `vm-setup.sh`. If you're familiar with `metal3-dev-env`, you will notice that most of these steps are copied from there, except for the addition of a new tool called `helm`. We will discuss more about helm in one of the following steps, but for now, let's run the script first (you might want to run it with `sudo`):

```bash
sudo ./vm-setup.sh
```

While we're at it, let's run the `./configure-minikube.sh` script as well. This is basically meant to make `minikube` accept insecured http connections, as we will later config it to work with an unsecured local registries.

```bash
./configure-minikube.sh
```

`handle-images.sh` will download needed images and push them to local registries, and run the `ironic_tls_setup.sh`, which will configure the certificates needed for TLS `ironic`. TLS is needed here since we will need to run `ironic` with `mariadb`, which is in turns a requirement for multiple-ironic scenario.

```bash
sudo ./handle-images.sh
```

### "Generate nodes"

`Fake-ipa` needs to have the information about the nodes that it will represent added to the config file before it gets started, and naturally we will, later on, need to provide `ironic` information of the same "nodes", so that the two sides accept one another. Hence, it's a good idea to generate those nodes beforehands and store the information in a file. We do that by running the script `generate_unique_nodes.sh`. This script reads the `N_NODES` value, which represents the number of nodes, from environment, and defaults to `100` if there's no such value.

```bash
./generate_unique_nodes.sh
```

The "nodes" are stored in a file called `nodes.json` in the pwd. This file will be taken into use in some next steps.

### Start-up sushy-tools and fake-ipa containers

Now that the nodes information is available, we can start up the `fake-ipa` container, and together with it, `sushy-tools` as well. What we need to do is to write a `conf.py` file with the configuration needed by either of these containers, and mount the directory to the container, so that the binaries inside could read it.

```bash
./start_containers
```

You may notice, from the script, that we use the envvar `N_SUSHY` to determine the number of `sushy-tools` containers. Reasons for why there can be more than 1 `sushy-tools` container is due to a speed limit in `sushy-tools`, which only allows it to handle around 100 nodes. To increase the number of nodes, we currently overcome the limit by increasing the number of `sushy-tools` and configure the nodes' endpoints accordingly.

### Start minikube and install ironic

With nodes information in place, we can go on to start up minikube, and then install `ironic` onto the minikube cluster.

```bash
./start-minikube.sh
```

In this script, we set up the minikube to work with `ironicendpoint`, just like in `metal3-dev-env`, as well as open some ports in the firewall, to make sure the traffic can flow from/to needed entities.

```bash
./install-ironic.sh
```

Besides `ironic`, we also install `cert-manager` (for TLS), and create an ironic client called `baremetal` to manage `ironic` from terminal.

Notice that to install `ironic`, we use the `helm` tool that we mentioned earlier. You can read more about it in its [official documentation](https://helm.sh/docs/). The helm chart we use to represent `ironic` is inside the directory `./ironic`. While we won't explain this chart in great details, here's some main points you may want to know:

- The `ironic` pod used in `metal3-dev-env`, which consists of several containers, was splited into smaller pods that run separatedly as followed:

   - `ironic` pod: consists of `ironic` and `ironic-httpd` containers.
   - `ironic-inspector` pod: consists of `dnsmasq` and `ironic-inspector` containers.
   - `mariadb` pod: consists of `mariadb` container.

Each of the pods is deployed as a helm's `deployment`, which means we can scale them as we wish. However, `ironic` only supports scaling of the `ironic` component, while the `ironic-inspector` and db will have to be unique.

This chart takes in the `sshKey` value to authenticate the `baremetal` client to connect to ironic, while the `ironicReplicas` value, which is a list of endpoints separated by spaces, determines how many `ironic` pods this deployment will have, and to what endpoints should we contact them. One nice feature from ironic is that we don't need to contact all of these `ironic` instances: since they share the same database, accessing any of them will be enough to query and control all the nodes.

### Create and inspect nodes

To ask ironic to register and inspect all the nodes we created in the previous step, without the help of BMO, we have to send commands directly to ironic. Luckily, there's already a command-line tool being populated by the script `install-ironic.sh`, which you can call by the command `baremetal`. In details, for each of the nodes, we will run `baremetal node create` to add the node to ironic, followed by `baremetal node manage`, and then `baremetal node inspect`. By the end of this process, all of the nodes will be successfully inspected.

To apply these steps to all of our nodes parallelly, we will use a small python script called `create_and_inspect_nodes.py`. The reason python is chosen instead of bash was just to take advantage of the great parallelism management in python to manage several nodes at the same time (Otherwise it would take a lot longer than a few hours to finish the process with 1000 nodes).

```bash
python create_and_inspect_nodes.py
```

## All at once

All of the aforementioned scripts can be ran at once by running the `./Init-environment.sh`. Available customizations can be found in `config.sh`.

- Configs can be set in `config.sh`:

   - `N_NODES`: Number of nodes to create and inspect
   - `N_SUSHY`: Number of `sushy-tools` containers to deploy
   - `IRONIC_ENDPOINTS`: The endpoints of ironics to use, separated by spaces.

As said, the number of endpoints put in `IRONIC_ENDPOINTS` equals the number of ironics that will be used.

### Example config

```bash
N_NODES=1000
N_SUSHY=10
IRONIC_ENDPOINTS="172.22.0.2 172.22.0.3 172.22.0.4 172.22.0.5"
```

This config means that there will be, in total, 1000 (fake) nodes created, of which each roughly 100 nodes will point to one of the 10 `sushy-tools` containers.

__NOTE__: To clean up everything, you can run the `./cleanup.sh` script.

# Requirements

This study was conducted on a VM with the following specs:

- CPUs: 20c
- RAM: 64Gb
- Hard disk: 750Gb
- OS: `CentOS9-20220330`
