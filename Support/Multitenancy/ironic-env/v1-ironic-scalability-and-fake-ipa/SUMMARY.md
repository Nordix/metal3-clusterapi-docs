# Multiple ironics setup

## Purposes

- This setup is a part of the study to deploy multiple instances of `ironic-conductor` to increase provisioning capacity.
- It takes into use the new [ipa simulating tool](https://review.opendev.org/c/openstack/sushy-tools/+/875366), which allows simulating inspection and provision for multiple baremetal nodes, without the need of real hardwares.
- One purpose of this study is to investigate if the current `ironic` pod could be divided into smaller parts, and if `ironic` is able to be scaled.

## Requirements

This study was conducted on a VM with the following specs:
- CPUs: 20c
- RAM: 64Gb
- Hard disk: 750Gb
- OS: `CentOS9-20220330`

## Configuration

- Configs can be set in `config.sh`:

   - `N_NODES`: Number of nodes to create and inspect
   - `N_SUSHY`: Number of `sushy-tools` containers to deploy
   - `IRONIC_ENDPOINTS`: The endpoints of ironics to use, separated by spaces.
The number of endpoints put in here equals the number of ironics that will be used.

Example config:

```bash
N_NODES=1000
N_SUSHY=10
IRONIC_ENDPOINTS="172.22.0.2 172.22.0.3 172.22.0.4 172.22.0.5"
```
This config means that there will be, in total, 1000 (fake) nodes created, of which each roughly 100 nodes will point to one of the 10 `sushy-tools` containers.

## Results

- The `ironic` pod used in `metal3-dev-env`, which consists of several containers, was splited into smaller pods that run separatedly as followed:
   - First pod: consists of `ironic` and `ironic-httpd` containers.
   - Second pod: consists of `dnsmasq` and `ironic-inspector` containers.
   - Third pod: consists of `mariadb` container.
