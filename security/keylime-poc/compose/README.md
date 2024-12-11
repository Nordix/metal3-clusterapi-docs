# Keylime in Docker Compose POC
<!-- cSpell:ignore keylime -->

Make a Proof of Concept of [Keylime in Docker Compose](compose/README.md).

This will also work as part of [Keylime Agent in k8s](../k8s/README.md) POC,
as Keylime Verifier, Registrar and Tenant will be outside k8s, but Agent inside.
This creates interesting problems to be solved as Agent traffic will need to
flow via Ingress/LoadBalancer and it cannot be reached via IP.

## Steps

1. docker compose installed
1. Keylime images built locally via upstream
   [build_locally.sh](https://github.com/keylime/keylime/blob/master/docker/release/build_locally.sh)
   (we need unreleased fixes from `master`).
1. `docker compose up --build` to launch it
1. `./tenant.sh -c add` to verify stack works and agent gets added to verifier,
   with EK certificate from software TPM.

After this, feel free to play with `./tenant.sh`.
