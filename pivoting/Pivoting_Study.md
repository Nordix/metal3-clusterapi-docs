# Pivoting Study
## Steps
* Fetch:
    * Nordix/metal3-dev-env:test/pivoting-kashif branch
    * Nordix/cluster-api-provider-baremetal:test/pivoting-kashif
    * Nordix/cluster-api-provider-baremetal:test/pivoting-kashif
** Notes: These branches might not be rebased on current upstream branch. This is my working branch.

* Make sure you have the ```provider-components.yaml``` in ```cluster-api-provider-baremetal\examples\_out``` directory. ```make deploy ``` would create this. 

* Make a copy of it and create ```provider-components-target.yaml```. Assuming that, you are creating the target clusters in ```ubuntu```, change the ```eth2``` to ```enp1s0``` in ```config-map``` section of ```provider-components-target.yaml```.

* Do the following steps:
```
    cd ~/metal3-dev-env
    source v1alpha2.sh
    make 
    
    # Wait for the environment to be up. 
    ./scripts/v1alpha2/create_cluster.sh
    ./scripts/v1alpha2/create_controlplane.sh 
    
    cp ~/.kube/config source.yaml
    # Check the provisioned bmh's ip 
    scp ubuntu@192.168.111.20:/home/ubuntu/.kube/config target.yaml
    
    cd ~/go/src/sigs.k8s.io/cluster-api/cmd/clusterctl/
    ./clusterctl alpha phases pivot -p ~/provider-components-target.yaml  -s ~/metal3-dev-env/source.yaml -t ~/metal3-dev-env/target.yaml -v 5
```
* These steps should pivot the controllers, the cluster-api objects, capbm-objects, baremetalhosts and secrets. 
