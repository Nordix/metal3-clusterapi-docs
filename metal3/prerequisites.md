# Deployment of Metal3 on vanilla K8s cluster
To deploy metal3-components on vanilla K8s cluster, the following prerequisites
have to be met:
1. **Ironic should have access to layer-2 network for provisioning.**
2. **Node images container is running and reachable**
3. **Ironic-bmo-configmap is populated correctly**

We elaborate these points in detail here:
1. Ironic should have access to layer-2 network for provisioning. And on top of that the network should be configured so that ironic can reach the networking service for DHCP, PXE boot and other requirements.It is also required to provide ironic with the MAC address(es) of each node that it is provisioning so that it can pass this information to networking service for DHCP and PXE boot configuration.

2. The container containing node images volume should be running and reachable.
It is called the `httpd-infra` container in metal3-dev-env, which runs on ironic
image and contains the node images and some other required packages metal3 components to run. The following tree structure shows an example of the volume mounted in the container with the required images:

```ini
/shared/
├── html
│   ├── dualboot.ipxe
│   ├── images
│   │   ├── bionic-server-cloudimg-amd64.img
│   │   ├── bionic-server-cloudimg-amd64.img.md5sum
│   │   ├── ironic-python-agent-1862f800-59e2c9cab7e95
│   │   │   ├── ironic-python-agent.initramfs
│   │   │   ├── ironic-python-agent.kernel
│   │   │   ├── ironic-python-agent.tar
│   │   │   └── ironic-python-agent.tar.headers
│   │   ├── ironic-python-agent.initramfs -> ironic-python-agent-1862f800-59e2c9cab7e95/ironic-python-agent.initramfs
│   │   ├── ironic-python-agent.kernel -> ironic-python-agent-1862f800-59e2c9cab7e95/ironic-python-agent.kernel
│   │   └── ironic-python-agent.tar.headers -> ironic-python-agent-1862f800-59e2c9cab7e95/ironic-python-agent.tar.headers
│   ├── inspector.ipxe
│   └── uefi_esp.img
└── tmp


```

3. The environments variables defined in `ironic-bmo-configmap` required for `Baremetal Operator` deployment needs to be defined prior to deploying the
provider components in management cluster:

```sh
  PROVISIONING_IP=$CLUSTER_PROVISIONING_IP
  PROVISIONING_INTERFACE=$CLUSTER_PROVISIONING_INTERFACE
  PROVISIONING_CIDR=$PROVISIONING_CIDR
  DHCP_RANGE=$CLUSTER_DHCP_RANGE
  DEPLOY_KERNEL_URL=http://$CLUSTER_URL_HOST:6180/images/ironic-python-agent.kernel
  DEPLOY_RAMDISK_URL=http://$CLUSTER_URL_HOST:6180/images/ironic-python-agent.initramfs
  IRONIC_ENDPOINT=http://$CLUSTER_URL_HOST:6385/v1/
  IRONIC_INSPECTOR_ENDPOINT=http://$CLUSTER_URL_HOST:5050/v1/
  CACHEURL=http://$PROVISIONING_URL_HOST/images
```

This is an example representation of the environment variables which are
expected in `Baremetal Operator` deployment. This example actually shows the
environment variables also which are used in `metal3-dev-env` to populate the
configmap. This can be replaced by any variables in vanilla K8s cluster. It is
only important that the configmap variables are populated correctly so that
the ironic environment is reachable.
