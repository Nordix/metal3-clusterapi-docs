# e2e upgrade 

## Introduction

## Manual upgrade

## Use cases
### Upgrade kubeadm, kubelet and kubectl versions
Upgrade supported from current minor to next minor (e.g 1.16 to 1.17).
Details in https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/

* **upgrade with one extra node (or several extra nodes)**
  * additional resource need, no capacity impact
  * join node with new version (kubeadm join)
    * workers with new k8s version can join the cluster but the workers will stay in 'NotReady' state until
      any control-plane node is upgraded to the new k8s version 
  * remove the old node from the cluster (kubeadm reset -f)
  * Example cluster running on top of CentOS with loadbalancer, master1, 2, 3 and worker1, 2
    * details described in README.md inside usecases/upgrade-with-one-extra-node.zip

* **upgrade in place**
  * capacity decrease during upgrade due to scale-in scale-out
    * cordon the node to be upgraded and once finished, uncordon it
  * trigger upgrade with 'kubeadm upgrade', nodes are upgraded sequentially

* **upgrade with only one worker**
  * scheduling is allowed on master(s) to avoid service downtime, capacity impact
    * enable scheduling, remove taints 'kubectl taint nodes --all node-role.kubernetes.io/master-'
    * disable scheduling, set taint back 'kubectl taint nodes control-plane-1 control-plane-1=DoNotSchedulePods:NoSchedule'

### Add/replace nodes to an existing cluster
  * https://kubernetes.io/docs/setup/release/version-skew-policy/#supported-version-skew
  * Kubeadm upgrade is not used in this case
  * Add/replace should be supported between Kubernetes minor versions, e.g 1.16 to 1.17.
  * Example cluster running on top of CentOS with loadbalancer, master1, 2, 3, XX and worker1, 2
    * details described in README.md inside usecases/Add_replace_nodes_to_cluster.zip

### Image update
  * https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-interactive/
  * https://medium.com/platformer-blog/enable-rolling-updates-in-kubernetes-with-zero-downtime-31d7ec388c81
    * rolling update
        * readiness probe secures the incoming requests being served at all times, "old" pod termination started after new ones are ready
        * create a cluster, use e.g usecases/Add_replace_nodes_to_cluster.zip
  * image updating can be tested in the following way

```sh
kubectl get nodes -owide

- deploy nginx to running cluster
kubectl apply -f https://k8s.io/examples/application/deployment.yaml

kubectl get deployment --all-namespaces
kubectl get all --all-namespaces
kubectl get pods -owide

kubectl describe pods <nginx-deployment-pod-id>

- trigger image update by changing image version (chosen version in this example is 1.17.0)
kubectl set image deployments/nginx-deployment nginx=nginx:1.17.0

kubectl get all --all-namespaces
kubectl rollout status deployments/nginx-deployment

- rollback to from version
kubectl rollout undo deployments/nginx-deployment
kubectl rollout status deployments/nginx-deployment
```

## References
