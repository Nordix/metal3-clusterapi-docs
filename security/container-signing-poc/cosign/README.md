<!-- cSpell:ignore oras,kyverno,airgap,rsassa,pkcs,sigstore -->

# Cosign POC

This POC aims to provide a Proof-of-Concept for using cosign to sign images
using external signing service. It is complemented by the
[Oras](../oras/README.md) and [Kyverno](../kyverno/README.md) parts to achieve
full e2e POC.

**References:**

1. [Cosign container signature spec](https://github.com/sigstore/cosign/blob/main/specs/SIGNATURE_SPEC.md)
is a must read.
1. [Someone else doing the same](https://github.com/mvazquezc/mvazquezc.github.io/blob/85f301c3c3b8576a599e03470a3a76c600d6a586/content/posts/2024-04-25-signing-verifying-container-images-with-cosign/index.md)

**TODO LIST**:

- Change to external signer requested compatible signature
   - Needs [cosign patch](https://github.com/sigstore/cosign/pull/3917) to work
   - NOTE: cosign will not accept such trivial patch, see longer discussion
      [here](#cosign-signing-algorithm-support)
- Use Oras to move signature to prod registry
   - "cosign save ..." can do what Oras does as well!
- Verify the signature in K8s cluster, with Kyverno ClusterPolicy

## Preparation

NOTE: all this is done by `make test`, this is just explaining what it does.

1. Verify basic tools exist

   We need three tools installed and available in PATH:

   - docker
   - cosign
   - openssl

1. Run local registry where we can upload images and signatures

   Commonly, `docker run -d --restart=always -p 127.0.0.1:5003:5000 registry:2`
   does the trick.

1. Push public alpine image to a local registry for testing

   ```sh
   docker pull alpine:3.20.3
   docker tag alpine:3.20.3 127.0.0.1:5003/alpine:3.20.3
   docker push 127.0.0.1:5003/alpine:3.20.3
   ```

1. Generate certificates for signing

   ```sh
   ./scripts/gencrt.sh
   ```

   Certificate config files to be simplified further.

## Signing

1. Generate payload for local image for signing

   ```sh
   cosign generate 127.0.0.1:5003/alpine:3.20.3 > output/payload.json
   ```

   The file `output/payload.json` is simple:

   ```json
   {
      "critical": {
         "identity": {
            "docker-reference": "127.0.0.1:5003/alpine"
         },
         "image": {
            "docker-manifest-digest": "sha256:33735bd63cf84d7e388d9f6d297d348c523c044410f553bd878c6d7829612735"
         },
         "type": "cosign container image signature"
      },
      "optional": null
   }
   ```

1. Sign it and convert to base64

   SHA512 with PSS padding is the wanted state. Note that it DOES NOT WORK
   without cosign patch. IN PROGRESS.

   ```sh
   # Sign the payload with SHA256 - ONLY ONE THAT WORKS BY DEFAULT
   openssl dgst -sha256 -sign keys/leaf.key \
      -out output/payload.sig output/payload.json
   base64 output/payload.sig > output/payloadbase64.sig
   ```

   The content of the file `output/payloadbase64.sig` looks like following:

   ```console
   MEUCIQDfcf0R+9nNACTQVxsXmlWXavKXWwCQuknLFbzknDRzkgIgVPLD7NUquGlJ+sQHQFziujKv
   T1Zck4v6ZOG4LeLonKU=
   ```

   Signatures are binary, and thus base64 encoded.

1. Upload signature to the registry

   ```sh
   cosign attach signature --payload output/payload.json \
      --signature output/payloadbase64.sig 127.0.0.1:5000/alpine:3.20.3
   ```

## Verifying

We need to verify with cosign. Note that SHA512/PSS do not work without patch.

For flags, we need to ignore the identity/issuer with regex `.*`.
We also need to ignore SCT. `--private-infrastructure` avoids transparency log
queries, so no `--insecure-ignore-tlog` needed.

```sh
cosign verify \
    --cert keys/leaf.crt \
    --cert-chain keys/certificate_chain.pem \
    --certificate-identity-regexp '.*' \
    --certificate-oidc-issuer-regexp '.*' \
    --private-infrastructure \
    --insecure-ignore-sct \
    "127.0.0.1:5003/alpine:3.20.3"
```

Which will succeed with some disclaimers:

```console
WARNING: Skipping tlog verification is an insecure practice that lacks of
transparency and auditability verification for the signature.

Verification for 127.0.0.1:5003/alpine:3.20.3 --
The following checks were performed on each of these signatures:
- The cosign claims were validated
- The signatures were verified against the specified public key

[{"critical":{"identity":{"docker-reference":"127.0.0.1:5003/alpine"},"image":{"docker-manifest-digest":"sha256:33735bd63cf84d7e388d9f6d297d348c523c044410f553bd878c6d7829612735"},"type":"cosign container image signature"},"optional":null}]
```

## Cosign signing algorithm support

Sigstore/Cosign community does not what SHA512/PSS support unless it is covering
their entire ecosystem. See [summary](https://github.com/sigstore/cosign/pull/3917#issuecomment-2451334036)
in this issue.

Some references:

- [Issue from 2022 for allowing configurability](https://github.com/sigstore/cosign/issues/1775)
- [Add --signing-algorithm flag PR](https://github.com/sigstore/cosign/pull/3497)
- [Simple PSS/SHA512 support PR for verify](https://github.com/sigstore/cosign/pull/3917)
- [Slack discussion about it](https://sigstore.slack.com/archives/C01PZKDL4DP/p1730288293793379)
