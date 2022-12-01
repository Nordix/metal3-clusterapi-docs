# makenv

Deploy metal3 environment with multiple instances of `bmo/ironic` and `capi/capm3` providers watching different namespaces `test1` and `test2`

## Requirements

Machine: `8c / 32gb / 200gb`
OS: `CentOS9-20220330`

Tools: `sudo yum -y install git wget podman-catatonit podman`

## Run

```bash
git clone https://github.com/Nordix/metal3-clusterapi-docs
cd metal3-clusterapi-docs/CCD-support/Multitenancy/capi_capm3-mult-instances
./Init-environment.sh
```
