# Rotation of CA certificates in a Kubernetes cluster

A Kubernetes cluster uses the following certificate authorities (CAs) for its
operation:

- kubernetes-ca/cluster-ca: CA for most Kubernetes related tasks
- etcd-ca: CA for etcd
- kubernetes-front-proxy-ca: CA for front proxy

In addition, a public/private key pair (`sa.pub`, `sa.key`) is used to issue
the credentials for service accounts. Details of the certificates used in the
cluster can be found [in the Kubernetes
documentation](https://kubernetes.io/docs/setup/best-practices/certificates/).

At some point of time it may be required to use new cryptographic secrets in
the cluster due to, e.g., expiry of certificates, regulatory reasons, or
leakage of secrets. In this study, we collect information on required actions
to make the rotation of the CAs in the cluster possible.

## How to rotate CAs

The rotation should happen in a cluster set up with CAPI, i.e., the machines
are immutable, and without downtime of the cluster. To prevent a downtime while
maintaining a operational cluster, the nodes in the cluster need to trust two
CAs for every CA type for some amount of time. Given these requirements, only
the following phases would be possible:

1. **Establish trust with the new CAs:** All nodes in the cluster need to know
   about the new CAs and need to trust them.
2. **Rotate the CAs:** Switch to the new CAs by updating the key on the
   control plane nodes.
3. **Recreate all certificates:** For nodes this requires reprovisioning, new
   user account credentials (e.g., `admin.conf`) need to be distributed to the
   users.
4. **Distrust the old CAs:** The old CA certificates need to be removed from
   all nodes.

Step 1, 3 and 4 require reprovisioning of all nodes in the cluster at the
moment as the certificates are placed on the hosts on creation and are not
updated later on. Step 2 requires only reprovisioning of the control plane
nodes.

## Rotation of the etcd CA and the front-proxy CA

These certificates can be rotated through cluster-api with the phases described before.

For this, new CA certificates are created for etcd and front-proxy. For the
tests, we created new ones that were completely independent from the existing
certificates. We used the commands from the [cluster-api
book](https://cluster-api.sigs.k8s.io/tasks/certs/using-custom-certificates.html):

```bash
openssl req -x509 -subj “/CN=ETCD CA” -new -newkey rsa:2048 -nodes -keyout new-etcd.key -sha256 -days 3650 -out new-etcd.crt
openssl req -x509 -subj “/CN=Front-End Proxy” -new -newkey rsa:2048 -nodes -keyout new-front-proxy.key -sha256 -days 3650 -out new-front-proxy.crt
```

Then, we updated the secrets for the CAs to each contain the old certificate,
the new certificate, and the old key. By reprovisioning the control plane
nodes, this gets known to the cluster (phase 1). The cluster stays operational
during the rolling upgrade of the nodes.

Next, the secrets are updated again to include the new certificate, the old
certificate, and the new key. By reprovisioning the control plane nodes, they
now use the new CAs and the certificates on the nodes are already signed by the
new CAs.

After that, the secrets can be updated again to remove the old certificate from
them. After another upgrade of the control plane nodes, they only know about
the new CA with the new key.

## Rotation of the cluster CA

The rotation of the cluster CA could follow the same steps but turns out to
have more issues. The first difference is that the provisioning of worker nodes
does not only rely on the secrets stored in the management cluster but also on
a configmap called cluster-info in the target cluster. This configmap contains
a copy of the CA certificate that needs to be updated as well. With the updated
cluster-info, newly created or upgraded worker nodes receive the set of old and
new certificate. The worker nodes with both CA certificates correctly trust the
control plane certificates signed by the old CA.

However, after phase 1, i.e., rolling out the old certificate, the new
certificate, and the old key to the control plane nodes, the control plane can
not issue new certificates to worker nodes because the CSRSigningController can
not deal with two certificates in the CA file (this issue would need to be
fixed in kubernetes or kubeadm, see
[kubeadm#1350](https://github.com/kubernetes/kubeadm/issues/1350)). Therefore,
we could not investigate further than that.

Such issues may arise in multiple places in the kubernetes code base but they
are probably fixable by searching for a certificate in the file that matches
the private key (. Another option would be to introduce new CLI options or
configuration options to be able to distinguish between the file containing all
trusted CAs and the containing the CA certificate that should be used for
signing.

After all nodes have certificates signed by the new CA (in phase 3), the
certificates outside of the cluster need to be renewed. This foremost means to
update user credentials, e.g., `admin.conf`. This can not be done by
kubernetes/cluster-api but requires some operational process. The service
account secrets also contain the CA certificates and may therefore need to be
updated in this step.

## Rotation of the Service Account key pair

In addition to the authentication between the nodes and authentication of user
credentials, which are both based on PKIs, there are the service account
credentials. These credentials contain a JWT (JSON Web Token) which is signed
with the private key `sa.key` and gets verified with the public key `sa.pub`.
This process does not allow to check the tokens against multiple trusted public
keys right now. The issue is tracked in
[kubernetes#20165](https://github.com/kubernetes/kubernetes/issues/20165).

Therefore, it is not possible right now to rotate the service account keys
without endangering the functioning of the deployed pods.

## Technical details

Trusting two CAs for communication should work in the most places already
because kubernetes and etcd both use `go.etcd.io/etcd/pkg/transport` for TLS
connections which correctly implements the certificate verification against
multiple CAs.

## Tests done and their results

All test were done using a working cluster with three control plane nodes and
three worker nodes; deployed using CAPD. When new certificates are used, they
were generated according to the [cluster-api
book](https://cluster-api.sigs.k8s.io/tasks/certs/using-custom-certificates.html).

For all the yaml files used in the tests, there are examples in this repository.

### Test 1: Replacing cluster-ca secret in management cluster

- Start with a fresh cluster
- Export existing cluster CA certificate and key from the management cluster

  ```sh
  kubectl get secrets my-cluster-ca -o json | jq -r '.data."tls.crt"' | base64 --decode > my-cluster-ca.crt
  kubectl get secrets my-cluster-ca -o json | jq -r '.data."tls.key"' | base64 --decode > my-cluster-ca.key
  ```

- Replace the certificate in the my-cluster secret with a combination of the
  new CA certificate and the old CA certificate and replace the key in the
  secret with the new key

  ```sh
  # To combine certificates for updating the secret
  # Order is probably important, certificate matching the key first
  cat my-cluster-ca.crt new-my-cluster-ca.crt | base64
  cat my-cluster-ca.key | base64

  kubectl apply -f update-ca.yaml # For cluster-ca secret
  ```

- Delete one worker to force reprovisioning
- Result: Worker can not be provisioned, problem when checking the pinned certificates
- Finding: Cluster certificate is also present in the cluster-info configmap inside the cluster
- Same problem when deleting controlplane node to recreate it

### Test 2: updating cluster-ca secret to include new cert

- Start with a fresh cluster
- Export existing cluster CA certificate and key from the management cluster as
  before
- Replace the certificate in the my-cluster secret with a combination of the
  old CA certificate and the new CA certificate and leave the old key in the
  secret (see test 1)
- Delete control plane node to force reprovisioning
- Result: Works, new node joins the existing control plane and has new
  certificates
- Delete worker node to force reprovisioning
- Result: Works, the node joims the existing cluster, but `pki/ca.crt` contains
  only the old CA certificate (probably taken from the cluster-info configmap)

### Test 3: update cluster-ca secret and cluster-info configmap

- Start with a fresh cluster
- Export existing cluster CA certificate and key from the management cluster as
  before
- Retrieve current cluster-info configmap from the target cluster

  ```sh
  kubectl --kubeconfig capi-kubeconfig get configmap --namespace kube-public cluster-info -o yaml > cluster-info.yaml
  ```

- Replace the certificate in the my-cluster secret with a combination of the
  old CA certificate and the new CA certificate and leave the old key in the
  secret (see test 1)
- Patch the cluster-info configmap in the target cluster to contain the same
  set of certificates as the secret

  ```sh
  kubectl --kubeconfig capi-kubeconfig patch -n kube-public configmap cluster-info --patch "$(cat cluster-info.yaml)"
  ```

- For automatic upgrade of the worker nodes:

  ```sh
  kubectl patch machinedeployments worker --type merge --patch "$(cat update-worker.yaml)"
  ```

- For automatic upgrade of the control plane nodes:

  ```sh
  # Create MachineTemplate with new name and label
  kubectl apply -f new-dockermachinetemplate.yaml
  # Patch kcp to use the new template, this triggers upgrade
  kubectl patch kcp my-controlplane --type merge --patch "$(cat update-controlplane.yaml)"
  ```

- Results:
   - Reprovisioning worker nodes is successful, `pki/ca.crt` contains both
    certificates
   - Reprovisioning control plane node is successful, `pki/ca.crt` contains both
    certificates
   - Cluster works during and after the upgrade

### Test 4: rotate cluster-ca key (after test 3)

- Reuse cluster after test 3
- Replace the certificate in the my-cluster secret and in the cluster-info
  configmap with a combination of the new CA certificate and the old CA
  certificate and replace the key in the secret with the new key
- Upgrade worker nodes so they use the new configuration
- Result: Upgrade fails, new workers can not be provisioned (bootstrap tokens
  for new nodes missing)
- Order of upgrades is important: after updating the control plane to have two
  CA certificates, no new bootstrap tokens are added to the cluster-info
  configmap; this prevents new (or upgraded) nodes from joining the cluster;
  however, the bootstrap token is generated as a secret; reason:
  CSRSigningController can not deal with two certificates

### Test 5: CA trust

- Start with a fresh cluster
- On one worker node:
   - Create a new CA certificate with openssl
   - Update ca.crt to include new CA certificate and old CA certificate (in that
    order)
   - Restart node
- Result: connection to control plane is possible --> trusting two certificates
  works

### Test 6: etcd and front-proxy certificates

- Start with a fresh cluster
- Export existing certificate and key for cluster-ca, etcd-ca and
  front-proxy-ca from the management cluster as before; retrieve cluster-info
  configmap from the target cluster
- Update CAs so each contains old CA certificate, new CA certificate and old
  key
   - For cluster-ca update secret and configmap as in test 3
   - For etcd and front-proxy, just secrets need to be updated, similar to test
    3 (see `update-etcd.yaml` and `update-proxy.yaml`)
- Upgrade control plane nodes as in test 3
- Result: Works, control plane is successfully upgraded

### Test 7: etcd and front-proxy certificates rotation

- Start with a fresh cluster
- Export existing certificate and key for etcd-ca and front-proxy-ca from the
  management cluster as before
- Update the secrets for etcd and front-proxy so each contains old CA
  certificate, new CA certificate and old key, do not change the cluster-ca
- Upgrade control plane nodes --> works, control plane is successfully updated
- Updated secrets again to contain: new CA certificate, old CA certificate, and
  new key
- Upgrade control plane nodes as before
- Results:
   - Works, control plane is successfully updated
   - No split brain during upgrade
   - Updated nodes do already have certificates signed by new CA
