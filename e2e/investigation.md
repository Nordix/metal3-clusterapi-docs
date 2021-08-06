# Study of end-to-end testing of CAPM3

## Abbreviations

- CAPM3: [Cluster API Metal3 provider](https://github.com/Nordix/cluster-api-provider-metal3/tree/master)
- e2e: end-to-end
- BDD: [Behavior-Driven Development](https://en.wikipedia.org/wiki/Behavior-driven_development)
- CAPI: [Cluster API](https://github.com/kubernetes-sigs/cluster-api)
- CI: Continuous Integration, in case of CAPM3 the CI tool is [Jenkins](https://jenkins.nordix.org/)

## Aim of the study

**Original problem**: e2e test execution takes too much time.

**Goal**: Original goal of the User Story was to investigate whether parallel execution of the e2e test
specifications is possible or not.

It was decided prior to the start of the study that the end-to-end testing will follow the BDD style test implementation and the following tools will
be used to implement the tests:

- The `Ginkgo` BDD test framework, more information can be found [here](https://onsi.github.io/ginkgo/#individual-specs-it)
- Gomega matcher library, more information can be found [here](https://onsi.github.io/gomega/)
- CAPI test framework, more information can be found [here](https://pkg.go.dev/sigs.k8s.io/cluster-api/test@v0.4.0/framework)

Additional documentation:

- CAPI test [documentation](https://cluster-api.sigs.k8s.io/developer/testing.html)
- CAPI e2e test [documentation](https://cluster-api.sigs.k8s.io/developer/e2e.html)

## Findings

It was established during the study that the actual problem is that the cleanup and
re-installation of the development environment (VMs and management cluster).

It would be very time consuming to run the cleanup and the re-installation process after each e2e test.

Because of the nature of the e2e tests there are inherent issues:

1. Not every test can run parallel to other tests in the same metal3-dev-env instance e.g.
pivoting needs to be executed before re-pivoting. Other example Updating the management cluster or
other objects in the cluster during an "upgrade test" might cause stability issues for other
tests in the same environment.

2. At the moment the cleanup process for e2e tests in `CAPM3` is not test specific.
There is no cleanup process implemented for individual e2e tests that would restore the dev-env to a state
from where other e2e tests could be started, this is partly the case because the restoration process is highly
dependent on the e2e test that was executed as some tests affect the configuration of the whole dev-env.

It has become clear that there are multiple ways to achieve the parallel test execution

## Possible solutions

### E2E test process restructuring

**GOAL**
Create a maintainable and configurable e2e test execution process

**NOTE**
   `Ginkgo` test specs can be executed in a parallel fashion as described [here](https://onsi.github.io/ginkgo/#parallel-specs).

The following features have to be implemented as part of restructuring.

**Feature**
Each individual test case should have it's own cleanup process that reverts the modifications
done by the test execution.
The cleanup process should aim to avoid re-installation of the
dev-env. In some cases like pivoting the cleanup process could be implemented as an other
test spec/case e.g "re-pivoting".

**Benefit**
The individual cleanup processes would provide a reusable development environment for developers who
run e2e tests on their own machines.

**Feature**
Test specs that would be executed in parallel mode should be grouped separately from the ones executed sequentially as
not all e2e test cases work well together. The tests that are grouped together as parallelly executable would be
executed by `Ginkgo`'s native parallel execution feature. The parallelly executed tests would run at the same time
in different namespaces on the same developer environment (same management cluster and same managed cluster(s)).

**Benefit**
`Ginkgo` parallel test execution can speed up a group of tests although not all of them.

**Feature**
All the `ginkgo test specs` ([It](https://onsi.github.io/ginkgo/#structuring-your-specs) function in ginkgo)
could be enabled/disabled individually e.g "make test-e2e pivoting update" etc.
An argument based selector logic would be implemented to enable-disable individual test specs or group of specs.
It would be the same as we handle arguments in case of e.g. "skipCleanup" flag. The arguments would be predefined and tied to individual
`specs` and the value of the argument would be a boolean that would be set to `false` when the test is blocked and `true` when
the test is selected for execution. `Groups` of tests could be grouped in different `ginkgo Describe blocks` but specs from different
`Descirbe` blocks could be enabled during the same test execution process as the selector logic would be on the `spec` level. By default
all the specs would be disabled and they could be enabled with command line arguments when the `got test` command is called in the
makefile.

**Benefit**
The implementation of individually executable test cases would provide the functionality to support multiple `Ginkgo` test execution
commands in the Makefile. The different `Ginkgo` test execution commands would execute a single group of tests and the individual tests
that belong to the group would be passed one by one to the `Ginkgo` test commands as command line arguments. The `Ginkgo` commands that
are execute a group of tests could be configured to do parallel execution or sequential execution based on what kind of tests are
present in the group. As a consequence of the aforementioned benefits the developers could selectively execute e2e tests on local
development environments without editing the `Ginkgo` code and also in CI it would be easy to create different jobs for different
groups of tests.

**Example of the test execution after restructuring has been implemented**
```Makefile
     .
     .
     .
     TEST_PIVOT=true
     TEST_REPIVOT=true
     UPDATE_TARGET_CLUSTER=true
     SOME_OTHER_TEST=true
     .
     .
     .
     # The following Ginkgo test executions could be tied to individual make command arguments e.g make e2e test pivoting-group
     # A sequential group
     time go test -v -timeout 24h -tags=e2e ./test/e2e/... -args \
	-ginkgo.v -ginkgo.trace -ginkgo.progress -ginkgo.noColor=$(GINKGO_NOCOLOR) \
	-e2e.artifacts-folder="$(ARTIFACTS)" \
     -e2e.test_pivot="${TEST_PIVOT}" \ # Enables pivoting test spec
     -e2e.test_repivot="${TEST_REPIVOT}" \ # Enables repivoting test spec
	-e2e.config="$(E2E_CONF_FILE_ENVSUBST)" \
	-e2e.skip-resource-cleanup=$(SKIP_CLEANUP) \
	-e2e.use-existing-cluster=$(SKIP_CREATE_MGMT_CLUSTER)
     # A parallel group
     time go test -v -timeout 24h -tags=e2e ./test/e2e/... -args \
	-ginkgo.p -ginkgo.v -ginkgo.trace -ginkgo.progress -ginkgo.noColor=$(GINKGO_NOCOLOR) \
	-e2e.artifacts-folder="$(ARTIFACTS)" \
     -e2e.test_update="${UPDATE_TARGET_CLUSTER}" \ # Enables update test spec
     -e2e.some_other_test="${SOME_OTHER_TEST}" \ # Enables some other test spec
	-e2e.config="$(E2E_CONF_FILE_ENVSUBST)" \
	-e2e.skip-resource-cleanup=$(SKIP_CLEANUP) \
	-e2e.use-existing-cluster=$(SKIP_CREATE_MGMT_CLUSTER)
     .
     .
     .
```

**NOTE**:
    Arbitrary number of sequential and parallel test groups could be defined thus arbitrary number of
    `Gingko` test execution command could be implemented in the `Makefile`.

**NOTE**:
    The creation of a `maintainable and configurable e2e test execution process` would not solve the issue that certain
    e2e tests take a long time to complete and can't be executed parallelly with other tests. The test process has to be be extended
    with additional features to save time especially in CI jobs. There are two different approach that has been considered to save time
    during e2e test execution.

### Options to speed up e2e tests


**Option 1 for time saving (pool of dev-envs)**:

**IDEA**
This solution requires the bootstrapping of separate dev-env instances
(both management cluster and target cluster) for individual e2e test cases.
With this approach the test execution would be still handled by `Ginkgo` parallel
test approach.

**CON**
This approach would require a "large" virtual machine as a build host thus it scales
poorly when new tests are added. This approach also creates a lot of technical depth and increases
the complexity of the tests as multiple separate dev-envs has to be setup and `Ginkgo` has to manage tests
paralelly on the separate dev-envs. There is a real possibility that the hardware requirements would be simply
to heavy to use this approach on local developer machines.

**Option 2 for time saving (solve it in CI)**:

**IDEA**
There would be individual CI jobs created for executing different set of the E2E test groups. There is no
need to create the same number of jobs as the number of test spec groups as e.g. one test job could execute a test group
that takes 30 minutes while another could execute 2 groups that take 15 minutes individually. This approach wouldn't
require additional test logic it would use the test features implemented as part of the `restructuring` process.

**CON**
This approach would require multiple hosts in CityCloud and it would not provide time saving for developers locally executing all the tests.

## Plan to proceed:

1. All the e2e tests has to be implemented.

2. Create a maintainable and configurable e2e test execution process. (restructuring)

3. E2e tests have to be speed up with either the `(pool of dev-envs)` or `(solve it in CI)` approach.

