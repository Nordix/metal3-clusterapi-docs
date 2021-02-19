# What is this?
This is a script that does CA rotation following steps in: https://kubernetes.io/docs/tasks/tls/manual-rotation-of-ca-certificates/

Note that this script can work only for the [CAPD][CAPD] workload cluster managed by a [CAPI][CAPD] cluster

# Prerequisite
A file named `capi-kuconfig` is needed in this directory to make the script work. This file is the kubeconfig file of the CAPD workload cluster.

# How to run
```sh
$ ./run.sh no
# Do the step 9 manually
$ ./run.sh rolling
```

# Note
The step 9 needs to do manually using `kubectl edit...`. Not sure why.

Run `./run.sh no` only once, otherwise it will overwrite the backup directory, result in the failure of the CA rotation process. 


[CAPD]: https://github.com/kubernetes-sigs/cluster-api-provider-docker
[CAPI]: https://github.com/kubernetes-sigs/cluster-api
