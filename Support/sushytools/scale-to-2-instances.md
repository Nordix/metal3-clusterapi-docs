# Scaling sushy-tools instances in Dev-env

Dev-env supports redfish BMC using sushy-tools running in a container and building the image from [https://github.com/metal3-io/ironic-image/tree/main/resources/sushy-tools](https://github.com/metal3-io/ironic-image/tree/main/resources/sushy-tools). To select redfish virtual media in the dev-env export the BMC driver environment variable `export BMC_DRIVER="redfish-virtualmedia"`.

Sushy-tools is backed by libvirt and it listens to redfish requests on the port `8000` by default. An instance of sushy-tools can see all the libvirt domains and that means multiple instances will be able to see the same domains.
e.g.: `curl http://localhost:8000/redfish/v1/Systems/`

To scale up the sushy-tools instances, it is sufficient to run multiple instances of the container and configure a different port for each instance in the sushy-tools configfile.

BMO uses the bmh spec to grep the target sushy-tools instance ip/port as shown below:

  ```yaml
  bmc:
        address: redfish-virtualmedia+http://192.168.111.1:8000/redfish/v1/Systems/acbffb42-64d1-4061-a6b0-492119d37fd5
        credentialsName: node-1-bmc-secret
  ```
