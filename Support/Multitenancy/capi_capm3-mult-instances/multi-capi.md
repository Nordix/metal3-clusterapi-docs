# Generate capi manifest

```bash
kustomize build config/default/ > capi.yaml
kustomize build bootstrap/kubeadm/config/default/ > kubeadm-bootstrap.yaml
kustomize build controlplane/kubeadm/config/default/ > kubeadm.yaml
```
