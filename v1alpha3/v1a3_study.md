# v1alpha3 impact study

## Cluster API v1alpha2 compared to v1alpha3

<https://github.com/kubernetes-sigs/cluster-api/blob/master/docs/book/src/providers/v1alpha2-to-v1alpha3.md>

* Update CAPBM CRD and controllers for v1alpha3 (for example the bootstrap data being in a secret, not in the machine status anymore, a creation of a secret might not be needed anymore)
* Migrate changes we have done in v1alpha2 to v1alpha3 version of CAPBM (v1alpha3 branch in Nordix is up to date with master)
* Checkout your work from here <https://github.com/Nordix/cluster-api-provider-baremetal/tree/v1alpha3>

## Setup CR conversion

Setup the webhooks and cert-manager to convert properly the CRs from/to v1alpha2 to/from v1alpha3.

Conversion webhooks are used in CAPI v1alpha2 which is a good reference for CAPBM webhook implementation.

* backwards compatibility for v1alpha2, CRs stored in etcd in v1alpha3 version
* controller-runtime libraries support admission webhooks and CRD conversion webhooks. Is there a need for admission webhooks?
* How the cert-manager installation should be handled in CAPBM? (Now we have installed it manually)
* kubebuilder suggest to us cert-manager for provisioning the certificates for the webhook server. We should then use cert-manager!

### Webhook related links

<https://book.kubebuilder.io/multiversion-tutorial/conversion-concepts.htmlok.kubebuilder.io/multiversion-tutorial/conversion-concepts.html>
<https://book.kubebuilder.io/reference/markers/webhook.htmlarkers/webhook.htmlarkers/webhook.htmlarkers/webhook.html>
<https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definition-versioning/#webhook-conversion>
<https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/#authenticate-apiservers>

### Cert-manager installation

<https://cert-manager.io/docs/installation/kubernetes/>

## Integrate the provider e2e test framework

<https://github.com/kubernetes-sigs/cluster-api/blob/master/docs/proposals/20191016-e2e-test-framework.md>

The crux of this proposal is to implement a test suite/framework/library that providers can use as e2e tests. It will not cover provider specific edge cases. Providers are still left to implement their own provider specific e2es.

This framework will be implemented using the Ginkgo/Gomega behavioral testing framework because that is the Kubernetes standard and does a good job of structuring and organizing behavior based tests.

* Study and implement the CAPI provider e2e test framework for Metal3 (Ginkgo)
* Mael refactored v1alpha2 tests using ginkgo? Could we use this work as starting point?

## Clusterctl redesign

<https://github.com/kubernetes-sigs/cluster-api/blob/master/docs/proposals/20191016-clusterctl-redesign.md>

### Initial Deployment

* As a Kubernetes operator, I’d like to have a simple way for clusterctl to install Cluster API providers into a management cluster, using a very limited set of resources and prerequisites, ideally from a laptop with something I can install with just a couple of terminal commands.
* As a Kubernetes operator, I’d like to have the ability to provision clusters on different providers, using the same management cluster.
* As a Kubernetes operator I would like to have a consistent user experience to configure and deploy clusters across cloud providers.

### Day Two Operations “Lifecycle Management”

* As a Kubernetes operator I would like to be able to install new Cluster API providers into a management cluster.
* As a Kubernetes operator I would like to be able to upgrade Cluster API components (including CRDs, controllers, etc).
* As a Kubernetes operator I would like to have a simple user experience to cleanly remove the Cluster API objects from a management cluster.

### Target Cluster Pivot Management

As a Kubernetes operator I would like to pivot Cluster API components from a management cluster to a target cluster.

### Provider Enablement

As a Cluster API provider developer, I would like to use my current implementation, or a new version, with clusterctl without recompiling.

## Intergrate machine health checking a.k.a node auto repair

<https://github.com/kubernetes-sigs/cluster-api/blob/master/docs/proposals/20191030-machine-health-checking.md>

* Enable opt in automated health checking and remediation of unhealthy nodes backed by machines for Metal3
* Use of the same node in repair?

### User story1

* As a user of a Workload Cluster, I only care about my app's availability, so I want my cluster infrastructure to be self-healing and the nodes to be remediated transparently in the case of failures

### User story2

* As an operator of a Management Cluster, I want my machines to be self-healing and to be recreated, resulting in a new healthy node in the case of matching my unhealthy criteria

## Loadbalancer

<https://github.com/kubernetes-sigs/cluster-api/issues/1850>
