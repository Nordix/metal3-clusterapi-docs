# Container Signing POC
<!-- cSpell:ignore kyverno,oras,sigstore,rebranded,pkcs,fulcio,rekor -->

This experiment is three-fold:

- [Signing images with Notation, especially with custom signers](notation/README.md)
- [Moving signatures from one registry to another](oras/README.md)
or
- [Signing with Cosign](cosign/README.md)
then
- [Validating the signing with Kyverno, in a Kind cluster](kyverno/README.md)

```mermaid
flowchart LR
   notation(Container signing with Notation)
   oras(Signature relocation with Oras)
   kyverno(Signature validation with Kyverno)
   cosign(Container signing and relocation with Cosign)

   notation-->oras
   oras-->kyverno
   cosign->kyverno
```

## TL;DR of the POC

Basically, the POC is finding the following related to Notation:

1. Notation is extendable with their plugin system
1. Plugin that can call any external script or binary to produce a signature has
   been implemented.
1. This allows any in-house, custom integration to private signer, regardless
   of the interface, even manual/email works (despite being brittle), without
   writing a full-fledged plugin with Go.
1. Notation can handle SHA512 with PSS, no problem
1. Kyverno can easily be configured to verify Notation signatures runtime, via
   their admission controller and pluggable policies.
1. Oras can be used to move containers and signatures from CI to production

And related to Cosign:

1. Cosign does not need plugins as it can be operated via command line to
   achieve external signing.
1. Cosign can also save and load images with signatures by itself, Oras is not
   needed
1. Cosign ecosystem can only handle RSA256 with PKCS#1. Anything other than
   those lack support as Sigstore wants support to be homogenous across all of
   its services, so implementing it is not trivial.
1. Kyverno can be used with Cosign the same as Notation, just a little bit more
   configuration needed in the manifest to disable transparency logs and SCTs.

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

Same happens with Cosign, with registry on port `5003`.

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

### Notes on Oras

Oras can handle any OCI binary or blob perfectly fine. With Cosign, using Oras
is not necessary as cosign CLI can load/save OCI containers identically to
Oras, which includes handling Cosign signatures attached to images.

### Notes on Cosign

While other components here are CNCF projects, Cosign is OpenSSF project. It is
developed on top of TUF framework, and is more of a continuation to Notary v1
than Notary v2/Notation ever was. Sigstore ecosystem contains not only Cosign,
but also Rekor and Fulcio for certificate management and transparency log servers,
as well as support for many languages, like Go, Python, Ruby, Java etc. This is
a strength and a weakness the same time, as mentioned before related to SHA256
hardcoding problem.
