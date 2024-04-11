# Container Signing POC

This experiment is three-fold:

1. [Signing images with Notation, especially with custom signers](notation/README.md)
1. [Moving signatures from one registry to another](oras/README.md)
1. [Validating the signing with Kyverno, in a Kind cluster](kyverno/README.md)

## TL;DR of the POC

Basically, the POC is finding the following:

1. Notation is extendable with their plugin system
1. Plugin that can call any external script or binary to produce a signature has
   been implemented.
1. This allows any in-house, custom integration to private signer, regardless
   of the interface, even manual/email works (despite being brittle), without
   writing a full-fledged plugin with Go.
1. Kyverno can easily be configured to verify Notation signatures runtime, via
   their admission controller and pluggable policies.
1. Oras can be used to move containers and signatures from CI to production

## e2e test

End-to-end test for this POC can be run with `make e2e` from this directory.
This does the following:

1. Build and install Notation plugin
1. Sign busybox image on local registry at port `5002`
1. Copy container and signature to another registry at port `5001`
1. Launch Kind cluster, install Kyverno and add ClusterPolicy for signature
   verification, and then run workloads that pass the verification and workloads
   that fail the verification to check, if the signing works e2e

End-to-end test will use the same certificates and same signature through the
whole chain for verify end-to-end functionality.

## Notes

### Notes on Notation

Notary V1 was part of TUF (The Update Framework) organization, yet separate
project in CNCF. Notary V2 has been rebranded as Notation to make the branding
clearer that it is based on different principles than Notary V1. Notary V1/TUF
has more strict "security principles", which also made it hard to use, and it
did not gain traction.

It should be noted that Notary V1 and Notary V2/Notation are completely different
projects, with claims of [hostile takeover](https://github.com/cncf/toc/issues/981)
by the new maintainers (Microsoft/Docker). CNCF TOC did not see it that way,
but funded a
[security audit](https://www.cncf.io/blog/2023/07/11/announcing-results-of-notation-security-audit-2023/)
for Notation, with no critical findings, but the argument from the Notary V1
folks is that the foundation of Notation security model is not good enough. This
design aspect was not part of the audit based on the findings.

### Notes on Kyverno

[Kyverno Image Signature verification](https://kyverno.io/docs/writing-policies/verify-images/)
is in beta.

Kyverno can also verify Sigstore Cosign signatures.

Kyverno is generic policy engine, capable of replacing OPA Gatekeeper etc.
