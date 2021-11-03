# Introduction
In this reported we have investigated the possibility to partition the CPU resources on Kubernetes into multiple pools instead of using only the K8s Native CPU manager. Different customized solutions exist, we have been trying to focus on openshift Performance Addon Operator and the Intel CPU manager for Kubernetes*(https://builders.intel.com/docs/networkbuilders/cpu-pin-and-isolation-in-kubernetes-app-note.pdf).

Natively k8s uses CPU manager to allocate for pods a set of cpus from the allocatable capacity, since Kubelet can specify set of cores to the system process and k8s process in a pool called reserved (or housekeeping) (https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/). The CPU manager when set to the static policy, provides a dynamic pool named Exclusive. this pool contains the Guaranteed pods having integer CPU request. The Exclusive cores will be dynamically excluded from the available cores (shared pool) then returned after the exit of the pod.  

Several third party solutions exist for applications that require deterministic performance. They mainly use the Isolcpus (https://sites.google.com/site/mrxpalmeiras/linux/cpu-isolation-and-proc-pinning) low-latency workload pods.


# Openshift

Openshift uses Performance Addon Operator (PAO) (https://github.com/openshift-kni/performance-addon-operators):
PAO is high-level operator managing lower-level operators mainly Machine config operator (MCO) (https://github.com/openshift/machine-config-operator) and Node tuning operator (NTO) (https://github.com/openshift/cluster-node-tuning-operator). Among the optimizations done using those operators is the CPU partitioning into two sets Isolated and reserved, this partitioning is based on the Isolcpus (https://sites.google.com/site/mrxpalmeiras/linux/cpu-isolation-and-proc-pinning).

Isolated: Based on Isolcpus this group of CPUs is isolated from all userspace process and can also add isolation form device iteration either for all the group or a specific cores. This pool will be dedicated to the worload.

Reserved (housekeeping):  A set of cores that are not part of the isolcpus this CPU is dedicated to the management process and pods. This group might still reserve a dynamic isolation for guaranteed pods. 

# CPU Manager for Kubernetes (CMK):
https://github.com/intel/CPU-Manager-for-Kubernetes
To isolate a process, the CPU Manager for Kubernetes* uses a wrapper program, taking arguments to run the given process and sets its 
core affinity based on which pool it is requesting a CPU from. 

CMK uses isolcpus to isolate a set of CPUs this set is divided into two pools, the first exclusive where each pod pin its cores and the other is shared among all pods assigned to this pool. 

Assigning a pod to an isolcpus core can be done also through the container runtime, however, using a subset of isolcpus as shared among multiple pods is still in investigation process.

The infra pool is the rest of cores that were not isolated using isolcpus and also from this set an optional pool to isolate cpu can be used (exclusive-non-isolcpus)

An interesting remark was mentioned that CMK can work also without using isolcpus but in this case it does not ensure the isolation from system process.

The plan for the usecase of patitioning CPU to 3 pools is to isolate a pool using isolcpus then assign the first group that needs lowest latency, the rest of CPUs should be managed by the native CPU manager since it is not aware of Isolcpus can reserve dynamic pool for guaranteed pods and the rest should be shared among other pods.

# CPU Pooler
There is also a solution that may create dynamic pools:  https://github.com/nokia/CPU-Pooler


