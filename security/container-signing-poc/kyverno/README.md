<!-- markdownlint-disable line-length -->
<!-- cSpell:ignore kyverno -->

# Image signature verification

Verifying image signatures runtime using Notation or Cosign, and Kyverno.

```mermaid
flowchart TB
    user(User)
    cert(CA public root cert)
    registry(Docker registry)
    kyverno(Kyverno admission controller)
    policy(Kyverno ClusterPolicy)
    cluster(k8s cluster)
    workload(Workload)

    user-->|load image and signature|registry
    user-->|install|kyverno
    user-->|apply workload|workload
    user-->|configures|policy
    policy-->|verifies signature with|kyverno
    cert-->|configured in|policy
    registry-->|create from|workload
    workload-->|runs in|cluster
    kyverno-->|admits|workload
    kyverno-->|reads signature from|registry
```

## Non-runtime verification

Verifying signatures with Notation "offline", please see
[Notation External Signer documentation](../notation/README.md).

Verifying signatures with Cosign "offline", please see
[Cosign documentation](../cosign/README.md).

## Runtime verification

For runtime signature verification, we use
[Kyverno with Notation](https://kyverno.io/docs/writing-policies/verify-images/notary/),
or [Kyverno with Cosign](https://kyverno.io/docs/writing-policies/verify-images/sigstore/)

This is part of e2e tests, suggested to run via repository top-level `Makefile`
via `make notation` or `make cosign`.

Kyverno's Makefile has `make setup` sets up the full setup with Kind cluster,
local registry. `make -f cosign.mk` will run Cosign tests in this prepared
cluster, while `make -f notation.mk` will run Notation tests.  `make clean` to
remove everything.
