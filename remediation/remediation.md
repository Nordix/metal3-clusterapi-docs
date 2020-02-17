## What is machine remediation?

Machine remediation enables automated recovery of nodes when failure
occurs. In the case of [CAPBM](https://github.com/metal3-io/cluster-api-provider-baremetal),
a `BareMetalMachine` has a reference pointing to a particular physcial host. In
case of the host failure for any reason (e.g. hard drive failures, power supply
failures, overheating, network port failure) machine remediation process should
be triggered automatically with very minimal or no user intervention to bring up
the machine back to the healthy state.

## Current implementation design

#### Machine HealthCheck Controller (MHC)

Machine Health Check Controller is responsible for health checking of a pool of
`Machine`s selected based on their label. To see the implementation of MHC
please check [openshift/machine-api-operator](https://github.com/openshift/machine-api-operator).

[MachineHealthCheck Controller](https://github.com/openshift/machine-api-operator/tree/master/pkg/controller/machinehealthcheck) (MHC) is responsible for watching
provisioning state of the machine. In case, _unhealthy_ node is detected, MHC
will set the `"reboot.metal3.io"` annotation on the corresponding `Machine`
object under `spec.provosioning` field in order to inform the _New Controller_
that _unhealthy_ machine is detected.

#### New Controller

When the `"reboot.metal3.io"` annotation is detected by the _New Controller_
on the `Machine` object, it will request from [Reboot API](https://github.com/metal3-io/baremetal-operator/pull/424) first power off then delete and then power on the node again.

## Unhealty criteria

A machine is considered as unhealthy when:
* Machine is in "failed" state
* Machine is in "provisioning" state for over the expected timeout
* ...

## Annotation and new fields

`Machine` object is expected to have `reboot.metal3.io` annotation which will
eventually trigger the remediation. The annotation can include several actions
as `reboot.metal3.io/{key}`, while `key` can be:

* PowerOff
* Delete
* PowerOn

To see more info regarding the annotation, please check [reboot-interface](https://github.com/metal3-io/metal3-docs/blob/master/design/reboot-interface.md)

`BareMetalHost` is expected to have the following new fields to be added under
the `status` section:
* `lastPoweredOn` - a time after which the Host was last booted using the
current image
* `pendingRebootSince`  - a time after which the Host was last booted using the
current image

## References:

* [Reboot API](https://github.com/metal3-io/baremetal-operator/pull/424)
* [Cluster-API Machine Health Checking](https://github.com/kubernetes-sigs/cluster-api/blob/bf51a2502f9007b531f6a9a2c1a4eae1586fb8ca/docs/proposals/20191030-machine-health-checking.md)
* [Openshift Machine Health Check controller](https://github.com/openshift/machine-api-operator/tree/master/pkg/controller/machinehealthcheck)
* [Reboot API Demo](https://www.youtube.com/watch?v=Y0gI5FnWLjk)
