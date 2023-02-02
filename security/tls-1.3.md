# TLS 1.3 support in Metal3 ecosystem

This document details the status of TLS 1.3 support in Metal3 ecosystem at the
time of writing (Jan 2023).

## Ecosystem

The Metal3 ecosystem refers to:

- BMO (Baremetal Operator, including Ironic)
- CAPI (Cluster API)
- CAPM3 (Cluster API Provider Metal3)
- cert-manager (Certificate Manager)
- kube-system (Kubernetes)
- Other (metal3-dev-env)

## Background information

### TLS 1.3 support in Golang

Starting in Go 1.13, TLS 1.3 support has been available. In Go 1.13, TLS 1.3 was
"opt-in", which led many projects adding `GODEBUG=tls13=1` to their
environments. This is only necessary and meaningful in Go 1.13. In later
versions TLS 1.3 is "opt-out", ie. you need to set TLS minimum and maximum
versions in project's `tls.Config`.

### TLS 1.0 and TLS 1.1 in Golang

Starting in Go 1.18, TLS 1.0 and TLS 1.1 have been disabled by default in
Golang. This leaves TLS 1.2 and TLS 1.3 as the only versions of TLS in Go 1.18
and later, unless project explicitly adds support for TLS 1.0 and TLS 1.1 back
via `tls.Config`.

### Configuration of min and max TLS versions

Many of the projects have only recently or not at all added support for
configuring minimum or maximum TLS versions. Without project's support for
configuration, TLS version negotiation is left to server and the client.

## Components

### BMO

**controller-manager**:

- Port `8443`: TLS 1.2, TLS 1.3

TLS version is not configurable with flags.

**ironic**:

For Ironic, it should be noted that:

- Ironic external endpoints are secured, while pod-internal traffic is not.
  `httpd` (Apache) handles TLS termination.
- IPA image serving from `httpd` port `6180` might be insecure due to PXE
  limitations (to be verified)
- Node image server is deployment specific. IPA client accessing the image
  server is limited to TLS 1.2 (see Oslo below)

Ports:

- Port `5049`: HTTP (Ironic Inspector API)
- Port `5050`: TLS 1.2, TLS 1.3 (httpd - Inspector endpoint)
- Port `6180`: HTTP (httpd - serving IPA images)
- Port `6385`: TLS 1.2, TLS 1.3 (httpd - Ironic endpoint)
- Port `6388`: HTTP (Ironic API)

Ironic endpoints support setting minimum and maximum TLS versions.

More info:

- [OSLO library does not support](https://docs.openstack.org/oslo.service/latest/configuration/index.html#ssl.version)
  TLS newer than 1.2 yet, TLS 1.3 support is planned
- [IPA TLS configuration documentation](https://docs.openstack.org//ironic-python-agent/latest/doc-ironic-python-agent.pdf)

### CAPI

All CAPI controllers support setting minimum and maximum TLS versions, with the
exception of `CAPD` which is a test provider.

**capi-kubeadm-bootstrap**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

**capi-kubeadm-control-plane**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

**capi-controller-manager**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

### CAPM3

**capm3-controller-manager**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

TLS version is not configurable with flags.

**ipam-controller-manager**:

- Port `9443`: TLS 1.2, TLS 1.3
- Port `9440`: HTTP (healthz)
- Port `8080`: HTTP (metrics)

TLS version is not configurable with flags.

### cert-manager

**cert-manager**:

- Port `9402`: HTTP (metrics)

**cert-manager-cainjector**:

- no listening ports

**cert-manager-webhook**:

- Port `10250`: TLS 1.2, TLS 1.3
- Port `6080`: HTTP (healthz)

### kube-system

**coredns**:

- Port `53` TCP/UDP: DNS
- Port `9153`: HTTP (metrics)

**etcd**:

For etcd, TLS 1.3 support was
[contributed by EST](https://github.com/etcd-io/etcd/pull/15156) and is expected
to be in the next patch release of etcd 3.5.x (estimated March 2023). Etcd
versions from `3.5.0` to `3.5.7` have hardcoded TLS 1.2 version. Some versions
of etcd `3.4.x` have support for TLS 1.3 as they lack this hardcoding of TLS
version, and using new enough Golang enables TLS 1.3 for them.

`etcd` will support setting minimum and maximum TLS version in the next release.

- Port `2379`: TLS 1.2
- Port `2380`: TLS 1.2

**apiserver**:

- Port `8443`: TLS 1.2, TLS 1.3

`apiserver` supports setting minimum and maximum TLS versions.

**controller-manager**:

- Port `8443`: TLS 1.2, TLS 1.3

`controller-manager` supports setting minimum and maximum TLS versions.

**kube-proxy**:

- Port `8443`: TLS 1.2, TLS 1.3

`kube-proxy` supports setting minimum and maximum TLS versions.

**scheduler**:

- Port `8443`: TLS 1.2, TLS 1.3

`scheduler` supports setting minimum and maximum TLS versions.

**kubelet**:

- Port `10250`: TLS 1.2, TLS 1.3

`kubelet` supports setting minimum and maximum TLS versions.

### Other (metal3-dev-env)

Tools in development environment are not secured, since hardening them would
hinder developer experience. Development environment is not for production use.

**httpd-infra**:

`httpd-infra` is deployment specific server, hosting node images.

- Port `80`: HTTP (Ironic httpd-infra)

**registry**:

- Port `5000`: HTTP

**sushy-tools**:

- Port `8000`: HTTP

**kind**:

- Port `44037`: TLS 1.2, TLS 1.3

**vbmc**:

- Port `50891`: non-HTTP

## Summary

TLS 1.3 is well supported in Metal3 ecosystem, with two exceptions:

- `etcd` where TLS 1.3 support is coming in the next release
- Ironic, where the Oslo library is not supporting TLS 1.3 (discussion on-going)

However, not all projects fully support configuration of TLS versions in case
TLS 1.3 would need to be enforced as the only supported TLS version.
