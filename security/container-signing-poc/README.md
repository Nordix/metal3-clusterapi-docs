# Container Signing POC

This experiment is two-fold:

1. [Signing images with Notation, especially with custom signers](notation/README.md)
1. [Moving signatures from one registry to another](oras/README.md)
1. [Validating the signing with Kyverno, in a Kind cluster](kyverno/README.md)

## TL;DR of the study

Basically, the POC is finding the following:

1. Notation is extendable with their plugin system
1. Plugin that can call any external script or binary to produce a signature has
   been implemented.
1. This allows any in-house, custom integration to private signer, regardless
   of the interface, even manual/email works (despite being brittle).
1. Kyverno can easily be configured to verify Notation signatures runtime, via
   their admission controller and pluggable policies.

## Notes on Notation

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

## Notes on Kyverno

[Kyverno Image Signature verification](https://kyverno.io/docs/writing-policies/verify-images/)
 is in beta.

Kyverno can also verify Sigstore Cosign signatures.

Kyverno is generic policy engine, capable of replacing OPA Gatekeeper etc.
