This document explains relationship between all the Custom Resources (CRs)
required to create the target Kubernetes cluster on bare metal machine and how
they reference to each other.

## Environment Variables

The user is required to set the following environment variables before applying
the CRs

```console
CLUSTER_NAME
IMAGE_CHECKSUM
IMAGE_URL
KUBERNETES_VERSION
SSH_PUB_KEY_CONTENT

```
## Cluster and Machine

![crs](crs_diagram.svg)
