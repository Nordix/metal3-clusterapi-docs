# Goal
- Manually rotate CA in the workload cluster: [1][1] 
- Update the management (CAPI) cluster secrets so it can interact with the workload cluster without any TLS problems

# How
Firstly, follow the instruction in the link until finishing step 9. In detail, at this stage:
- The workload cluster trusts both old and new CA certificates.
- The workload cluster uses the new CA key as the signing key. All the clients (kubelet, kubectl,...) adopt new certificates signed by the new CA
- The new CA certificate is added to the cluster-info configmap.
- The management cluster has no problem when connecting to the workload cluster since it continues to trust the old certificate. All the actions like scaling out, scaling in nodes are available.

Secondly, update the following secrets in the management cluster, so it changes to use the new CA:
- `<workload-cluster-name>-ca`: 
```sh
$ kubectl get secret <workload-cluster-name>-ca -oyaml
apiVersion: v1
data:
  tls.crt: <Put the new base64-encoded CA certificate to replace the old one>
  tls.key: <Put the new base64-encoded CA key to replace the old one>
  ...
```

- `<workload-ckuster-name>-kubeconfig`:
```sh
$ kubectl get secret <workload-clsuter-name>-kubeconfig -oyaml
apiVersion: v1
data:
  value: <Convert the content of the new kubeconfig file (/etc/kubernetes/admin.conf) to base64 code and put it here>
  ...
```

- `<workload-cluster-name>-proxy`:
```sh
$ kubectl get secret <workload-cluster-name>-proxy -oyaml
apiVersion: v1
data:
  tls.crt: <Put the new base64-encoded front-peoxy-ca.crt here>
  tls.key: <Put the new base64-encoded front-peoxy-ca.key here>
```

Finally, re-provisioning all KCP and worker nodes to make them adopt the new CA and generate new client certificates. 
After doing this step:
- The management cluster uses the new CA and generates new certificates signed by the new CA.
- All worker and KCP nodes use the new CA and have new certificates signed by the new CA certificate. 
- Both management cluster and workload cluster no longer trust the old CA.

# Note
- If we finish all the steps in the instruction [1][1], the management cluster can no longer connect to the workload cluster because because it is using the certificates signed by the old CA. In that case, we cannot re-provision KCP and worker nodes.
- Since we follow the manual step until step 9, we don't need to worry about the problem [2][2]

[1]: https://kubernetes.io/docs/tasks/tls/manual-rotation-of-ca-certificates/
[2]: https://github.com/kubernetes/kubeadm/issues/1350




