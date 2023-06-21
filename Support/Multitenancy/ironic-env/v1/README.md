# Multiple ironics setup

## Purposes

- This setup is a part of the study to deploy multiple instances of `ironic-conductor` to increase provisioning capacity.
- It takes into use the new [ipa simulating tool](https://review.opendev.org/c/openstack/sushy-tools/+/875366), which allows simulating inspection and provision for multiple baremetal nodes, without the need of real hardwares.
- One purpose of this study is to investigate if the current `ironic` pod could be divided into smaller parts, and if `ironic` is able to be scaled.

## Requirements

- Machine: `4c / 16gb / 100gb`
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

The `ironic` entity can be scaled up by deploying more instances of the first pod (a.k.a. `ironic` and `ironic-httpd`)

- Ironic cannot recover from `mariadb` failure:

```bash
baremetal node list

(pymysql.err.ProgrammingError) (1146, "Table 'ironic.nodes' doesn't exist")

[SQL: SELECT nodes.created_at, nodes.updated_at, nodes.version, nodes.id, nodes.uuid, nodes.instance_uuid, nodes.name, nodes.chassis_id, nodes.power_state, nodes.provision_state, nodes.driver, nodes.conductor_group, nodes.maintenance, nodes.owner, nodes.l
essee, nodes.allocation_id

FROM nodes ORDER BY nodes.id ASC

LIMIT %(param_1)s]

[parameters: {'param_1': 1000}]

(Background on this error at: https://sqlalche.me/e/14/f405) (HTTP 500)
```
