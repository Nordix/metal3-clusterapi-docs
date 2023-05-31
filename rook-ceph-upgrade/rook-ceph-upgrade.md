# Upgrade rook-ceph

We are going to upgrade the rook-ceph from downstream version to the master branch and after that to the latest release version.
I have installed rook and ceph according to the downstream version

## Version check for ceph from toolbox

```sh
1. kubectl -n rook-ceph exec -it rook-ceph-tools-6dc9679df5-hl2f2 bash
2. bash-4.4$ ceph version
ceph version 16.2.11 (3cf40e2dca667f68c6ce3ff5cd94f01e711af894) pacific (stable)
```

## Rook version check

```sh
3. export ROOK_OPERATOR_NAMESPACE=rook-ceph
4. export ROOK_CLUSTER_NAMESPACE=rook-ceph

5. kubectl -n $ROOK_CLUSTER_NAMESPACE get deployment -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{"rook-version="}{.metadata.labels.rook-version}{"\n"}{end}' | sort | uniq
rook-version=v1.10.1
```

## Upgrade from downstream version to the master branch of rook

```sh
6. git clone --single-branch --depth=1 --branch master https://github.com/rook/rook.git
7. cd rook/deploy/examples

# Apply the following files to have new changes in rook

8. kubectl apply -f common.yaml
   kubectl apply-f crds.yaml
   kubectl apply-f operator.yaml

# Apply the cluster.yaml files to have new changes in ceph
9. kubectl apply-f cluster.yaml
```

Version check during upgrade (It will show both old and new version of rook)

```sh
10. kubectl -n $ROOK_CLUSTER_NAMESPACE get deployment -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{"rook-version="}{.metadata.labels.rook-version}{"\n"}{end}' | sort | uniq
rook-version=v1.10.1 (old version)
rook-version=v1.11.0-alpha.0.363.g4af3f3784 (new version)
```

## After upgrading check rook version

```sh
11. kubectl -n $ROOK_CLUSTER_NAMESPACE get deployment -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{"rook-version="}{.metadata.labels.rook-version}{"\n"}{end}' | sort | uniq
rook-version=v1.11.0-alpha.0.363.g4af3f3784


12. kubectl -n $ROOK_CLUSTER_NAMESPACE get deployments -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"  \treq/upd/avl: "}{.spec.replicas}{"/"}{.status.updatedReplicas}{"/"}{.status.readyReplicas}{"  \trook-version="}{.metadata.labels.rook-version}{"\n"}{end}'
rook-ceph-crashcollector-test1-55b88586c9xg9px6-7t7sv      req/upd/avl: 1/1/1      rook-version=v1.11.0-alpha.0.363.g4af3f3784
rook-ceph-crashcollector-test1-55b88586c9xg9px6-f6dw4      req/upd/avl: 1/1/1      rook-version=v1.11.0-alpha.0.363.g4af3f3784
rook-ceph-crashcollector-test1-55b88586c9xg9px6-s2sjv      req/upd/avl: 1/1/1      rook-version=v1.11.0-alpha.0.363.g4af3f3784
rook-ceph-mgr-a      req/upd/avl: 1/1/1      rook-version=v1.11.0-alpha.0.363.g4af3f3784
rook-ceph-mgr-b      req/upd/avl: 1/1/1      rook-version=v1.11.0-alpha.0.363.g4af3f3784
rook-ceph-mon-a      req/upd/avl: 1/1/1      rook-version=v1.11.0-alpha.0.363.g4af3f3784
rook-ceph-mon-b      req/upd/avl: 1/1/1      rook-version=v1.11.0-alpha.0.363.g4af3f3784
rook-ceph-mon-c      req/upd/avl: 1/1/1      rook-version=v1.11.0-alpha.0.363.g4af3f3784
```

Check for ceph version from toolbox

```sh
13. kubectl -n rook-ceph exec -it rook-ceph-tools-6dc9679df5-hl2f2 bash
14. ceph version
ceph version 17.2.6 (d7ff0d10654d2280e08f1ab989c7cdf3064446a5) quincy (stable)
```

After upgrading to the master branch(v1.11.0-alpha.0.363.g4af3f3784) of rook and ceph (17.2.6), all Pods with rook-ceph namespace shoud be in running state.

## Upgrade to the latest release version for rook

```sh
15. git clone --single-branch --depth=1 --branch v1.11.6 https://github.com/rook/rook.git
16. kubectl apply -f crds.yaml -f common.yaml
17. kubectl -n rook-ceph set image deploy/rook-ceph-operator rook-ceph-operator=rook/ceph:v1.11.6

##*** there were no change in ceph image as it had the latest quintic version so it is unchanged
18. kubectl apply -f cluster.yaml


19. kubectl -n $ROOK_CLUSTER_NAMESPACE get deployments -l rook_cluster=$ROOK_CLUSTER_NAMESPACE -o jsonpath='{range .items[*]}{.metadata.name}{"  \treq/upd/avl: "}{.spec.replicas}{"/"}{.status.updatedReplicas}{"/"}{.status.readyReplicas}{"  \trook-version="}{.metadata.labels.rook-version}{"\n"}{end}'
rook-ceph-crashcollector-test1-55b88586c9xg9px6-7t7sv      req/upd/avl: 1/1/1      rook-version=v1.11.6
rook-ceph-crashcollector-test1-55b88586c9xg9px6-f6dw4      req/upd/avl: 1/1/1      rook-version=v1.11.6
rook-ceph-crashcollector-test1-55b88586c9xg9px6-s2sjv      req/upd/avl: 1/1/1      rook-version=v1.11.6
rook-ceph-mgr-a      req/upd/avl: 1/1/1      rook-version=v1.11.6
rook-ceph-mgr-b      req/upd/avl: 1/1/1      rook-version=v1.11.6
rook-ceph-mon-a      req/upd/avl: 1/1/1      rook-version=v1.11.6
rook-ceph-mon-b      req/upd/avl: 1/1/1      rook-version=v1.11.6
rook-ceph-mon-c      req/upd/avl: 1/1/1      rook-version=v1.11.6
```

Check for ceph version from toolbox

```sh
20. kubectl -n rook-ceph exec -it rook-ceph-tools-6dc9679df5-hl2f2 bash
21. ceph version
ceph version 17.2.6 (d7ff0d10654d2280e08f1ab989c7cdf3064446a5) quincy (stable)
```

After upgrading rook to the latest release branch which is v1.11.6, all pods with rook-ceph namespace shoud be in running state.

[Rook upgrade document](https://rook.io/docs/rook/latest/Upgrade/rook-upgrade/#1-update-common-resources-and-crds)
