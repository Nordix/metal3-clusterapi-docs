# Multitenancy

Deploy metal3 environment with two instances of `bmo/ironic` watching different namespaces `test1` and `test2`

## Requirements

Machine: `4c / 16gb / 100gb`
OS: `CentOS9-20220330`

tools: `sudo yum -y install git wget podman-catatonit podman`

## Run

```bash
git clone https://github.com/mboukhalfa/makenv.git
cd makenv
./Init-environment.sh
```

[Steps documentation](environment.md)
