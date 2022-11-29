# Metal3 OpenSSF Scorecards Evaluation

## Scorecards project

[Scorecards](https://github.com/ossf/scorecard) is an automated tool that assesses a number of important heuristics ("checks") associated with software security and assigns each check a score of 0-10. You can use these scores to understand specific areas to improve in order to strengthen the security posture of your project. You can also assess the risks that dependencies introduce, and make informed decisions about accepting these risks, evaluating alternative solutions, or working with the maintainers to make improvements.

### Running the evaluation

**GitHub token**
Set `GITHUB_TOKEN` to workaround rate limits, AND some checks are only available if you have maintainer rights in the project.
Read more [here](https://github.com/ossf/scorecard/blob/main/README.md#scorecard-checks)

- It has to be a classic token, and it needs basically all `read` rights you can tick off

**Running the scorecard tool**
You can run the tool via Docker or get pre-built binary from their releases

- Scorecard is available as a Docker container: `docker pull gcr.io/openssf/scorecard:stable`, OR
- Visit our latest [release page](https://github.com/ossf/scorecard/releases/latest) and download the correct zip file for your operating system.

```bash
# basic run
scorecard --repo=<github.com/org/repo>
# for more details, add --show-details
scorecard --repo=github.com/ossf-tests/scorecard-check-branch-protection-e2e --show-details
```

```bash
docker run -e GITHUB_AUTH_TOKEN=token gcr.io/openssf/scorecard:stable --show-details --repo=https://github.com/ossf/scorecard
```

Output options are: `default` (text) or `json`: These may be specified with the `--format` flag. For example, `--format=json`.

### Displaying the badges

<https://github.com/ossf/scorecard/blob/main/README.md>

- The easiest way to use Scorecards on GitHub projects you own is with the Scorecards GitHub Action. The Action runs on any repository change and issues alerts that maintainers can view in the repository’s Security tab. For more information, see the Scorecards GitHub Action installation instructions. <https://github.com/ossf/scorecard-action#installation>
- Enabling `publish_results: true` in Scorecards GitHub Actions also allows maintainers to display a Scorecard badge on their repository to show off their hard work. This badge also auto-updates for every change made to the repository. To include a badge on your project's repository, simply add the following markdown to your README: `[![OpenSSF Scorecard](https://api.securityscorecards.dev/projects/github.com/{owner}/{repo}/badge)](https://api.securityscorecards.dev/projects/github.com/{owner}/{repo})`

## Scorecard tests

| Test + link | Risk | Risk reason | Requirements | Failing repos (out of 18) |
|---|---|---|---|---|
| [Binary-Artifacts](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#binary-artifacts) | High | non-reviewable code | Determines if the project has generated executable (binary) artifacts in the source repository. | 0 |
| [Branch-Protection](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#branch-protection) | High | vulnerable to intentional malicious code injection | Determines if the default and release branches are protected with GitHub's branch protection settings. | ALL |
| [CI-Tests](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#ci-tests) | Low | possible unknown vulnerabilities | Determines if the project runs tests before pull requests are merged. | 10 |
| [CII-Best-Practices](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#cii-best-practices) | Low | possibly not following security best practices | Determines if the project has an OpenSSF (formerly CII) Best Practices Badge. | ALL |
| [Code-Review](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#code-review) | High | unintentional vulnerabilities or possible injection of malicious code | Determines if the project requires code review before pull requests (aka merge requests) are merged. | 4 |
| [Contributors](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#contributors) | Low | lower number of trusted code reviewers | Determines if the project has a set of contributors from multiple organizations (e.g., companies). | 0 |
| [Dangerous-Workflow](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#dangerous-workflow) | Critical | vulnerable to repository compromise | Determines if the project's GitHub Action workflows avoid dangerous patterns. | 0 |
| [Dependency-Update-Tool](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#dependency-update-tool) | High | possibly vulnerable to attacks on known flaws | Determines if the project uses a dependency update tool. | 14 |
| [Fuzzing](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#fuzzing) | Medium | possible vulnerabilities in code | Determines if the project uses fuzzing. | 17 |
| [License](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#license) | Low | possible impediment to security review | Determines if the project has defined a license. | 2 |
| [Maintained](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#maintained) | High | possibly unpatched vulnerabilities | Determines if the project is "actively maintained". | 7 |
| [Packaging](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#packaging) | Medium | users possibly missing security updates | Determines if the project is published as a package that others can easily download, install, easily update, and uninstall. | 0 |
| [Pinned-Dependencies](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#pinned-dependencies) | Medium | possible compromised dependencies | Determines if the project has declared and pinned the dependencies of its build process. | 14 |
| [SAST](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#sast) | Medium | possible unknown bugs | Determines if the project uses static code analysis. | ALL |
| [Security-Policy](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#security-policy) | Medium | possible insecure reporting of vulnerabilities | Determines if the project has published a security policy. | 15 |
| [Signed-Releases](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#signed-releases) | High | possibility of installing malicious releases | Determines if the project cryptographically signs release artifacts. | 4 |
| [Token-Permissions](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#token-permissions) | High | vulnerable to malicious code additions | Determines if the project's workflows follow the principle of least privilege. | 7 |
| [Vulnerabilities](https://github.com/ossf/scorecard/blob/c40859202d739b31fd060ac5b30d17326cd74275/docs/checks.md#vulnerabilities) | High | known vulnerabilities | Determines if the project has open, known unfixed vulnerabilities. | 0 |

### Binary-Artifacts

None of the repos have binary artifacts in the repo.

### Branch-Protection

All of the repositories have some sort of issue with branch protection.

*NOTE*: Scorecards that have been run without administrator access cannot check for "for administrator" items.

>Tier 1 Requirements (3/10 points):
>
> - Prevent force push
> - Prevent branch deletion
> - For administrators: Include administrator for review
>
>Tier 2 Requirements (6/10 points):
>
> - Required reviewers >=1 ​
> - For administrators: Strict status checks (require branches to be up-to-date before merging)
>
>Tier 3 Requirements (8/10 points):
>
> - Status checks defined
>
>Tier 4 Requirements (9/10 points):
>
> - Required reviewers >= 2
>
>Tier 5 Requirements (10/10 points):
>
> - For administrators: Dismiss stale reviews
> - For administrators: Require CODEOWNER review

### CI-Tests

We have roughly 50% of the repos that accept contributions without CI tests. Some of the repos have high score, but not 10/10, that might indicate that they have tests now, but not enough commits have passed through to reset the score.

### CII-Best-Practices

Only one repo has CII Best Practices badge in-progress. Others are missing it. As OpenSSF says in the following quote, achieving a passing mark is an achievement itself.

> The OpenSSF Best Practices badge has 3 tiers: `passing`, `silver`, and `gold`. We give full credit to projects that meet the passing criteria, which is a significant achievement for many projects. Lower scores represent a project that is at least working to achieve a badge, with increasingly more points awarded as more criteria are met.
>
> To earn the passing badge, the project MUST:
>
> - publish the process for reporting vulnerabilities on the project site
> - provide a working build system that can automatically rebuild the software from source code (where applicable)
> - have a general policy that tests will be added to an automated test suite when major new functionality is added
> - meet various cryptography criteria where applicable
> - have at least one primary developer who knows how to design secure software
> - have at least one primary developer who knows of common kinds of errors that lead to vulnerabilities in this kind of software (and at least one method to counter or mitigate each of them)
> - apply at least one static code analysis tool (beyond compiler warnings and "safe" language modes) to any proposed major production release.
>
> Some of these criteria overlap with other Scorecards checks.

### Code-Review

Few repositories where commits have been pushed directly to main without Code-Review. Code-review should be mandatory.

### Contributors

All repositories have enough contributors working for companies to receive full score.

### Dangerous-Workflow

No repository has identified dangerous workflows.

### Dependency-Update-Tool

Supported configurations:

- Signup for automatic dependency updates with `dependabot` or `renovatebot` and place the config file in the locations that are recommended by these tools.
- Unlike `dependabot`, `renovatebot` has support to migrate dockerfiles' dependencies from version pinning to hash pinning via the pinDigests setting without aditional manual effort.

### Fuzzing

Only a single repository has fuzzing enabled. Metal3 has requested CNCF assistance on enabling fuzzing.

Supported configurations:

- if the repository name is included in the `OSS-Fuzz` project list;
- if `ClusterFuzzLite` is deployed in the repository;
- if there are user-defined language-specified fuzzing functions (currently only supports `Go` fuzzing) in the repository.
- if it contains a `OneFuzz` integration detection file;

### License

We have 2 repositories that do not have proper license in place. These repositories should be fixed immediately.

### Maintained

7 repositories do not have enough contributions and discussion in issues within 90 days to be considered maintained.

### Packaging

No issues as no packaging is detected on any project.

### Pinned-Dependencies

Plenty of issues here. Main categories where the negative score comes from not pinning by hash:

- GitHub actions (GitHub-owned and 3rd-party-owned)
- Docker images
- Pip installs

### SAST

SAST tooling is not enabled/detected in any repository.

>The checks currently looks for known Github apps such as CodeQL (github-code-scanning) or SonarCloud in the recent (~30) merged PRs, or the use of "github/codeql-action" in a GitHub workflow. It also checks for the deprecated LGTM service until its forthcoming shutdown.

### Security-Policy

We have started inserting security policy files in repos, but `SECURITY_CONTACTS` is not valid file to this check.

> Remediation steps:
>
> - Place a security policy file `SECURITY.md` in the root directory of your repository. This makes it easily discoverable by a vulnerability reporter.
> - The file should contain information on what constitutes a vulnerability and a way to report it securely (e.g. issue tracker with private issue support, encrypted email with a published public key). Follow the coordinated vulnerability disclosure guidelines to respond to vulnerability disclosures.

An [organization wide community health files repository](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file) can provide for `SECURITY.md` for all repositories under an organization.

### Signed-Releases

We only have any release objects for couple of projects, but none of them are signed.

> This check looks for the following filenames in the project's last five release assets: `*.minisig`, `*.asc` (pgp), `*.sig`, `*.sign`, `*.intoto.jsonl`.
>
> If a signature is found in the assets for each release, a score of 8 is given. If a SLSA provenance file is found in the assets for each release (`*.intoto.jsonl`), the maximum score of 10 is given.
>
> Note: The check does not verify the signatures.
>
> Remediation steps:
>
> - Publish the release.
> - Generate a signing key.
> - Download the release as an archive locally.
> - Sign the release archive with this key (should output a signature file).
> - Attach the signature file next to the release archive.

### Token-Permissions

Some projects miss top-level permissions setup, and some just use tokens that have unnecessary permssions.

> Remediation steps:
>
> - Set permissions as read-all or contents: read as described in GitHub's [documentation](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#permissions).
> - To help determine the permissions needed for your workflows, you may use StepSecurity's [online tool](https://app.stepsecurity.io/) by ticking the "Restrict permissions for GITHUB_TOKEN". You may also tick the "Pin actions to a full length commit SHA" to fix issues found by the Pinned-dependencies check.

### Vulnerabilities

No repository has open vulnerabilities identified.

>This check determines whether the project has open, unfixed vulnerabilities using the [OSV (Open Source Vulnerabilities)](https://osv.dev/) service. An open vulnerability is readily exploited by attackers and should be fixed as soon as possible.

## Scorecard findings

Checks per upstream organization, and repository, with short analysis why check has failed.

Note: Checks with full (10/10) scores are omitted from the tables.

### Kubernetes-sigs

CAPI and CAPO are important parts of Metal3 ecosystem. Their upstream is at `kubernetes-sigs` organization.

#### cluster-api-provider-openstack

<https://github.com/kubernetes-sigs/cluster-api-provider-openstack>

Generic score: `6.6`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | CodeOwner review not required in "main" or "release-0.6", Required reviewers is 0 in "main" and "release-0.6" |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| SAST | 0/10 | No SAST checks |
| Signed-Releases | 0/10 | No signatures |

#### cluster-api

<https://github.com/kubernetes-sigs/cluster-api>

Generic score: `7.0`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | CodeOwner review not required in "main", Required reviewers is 0 in "main" |
| CII-Best-Practices | 2/10 | In-progress self-assessment |
| Pinned-Dependencies | 5/10 | Not all deps (Github actions, Dockerfiles) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Signed-Releases | 0/10 | No signatures |
| Token-Permissions | 0/10 | Github workflows using token with too many permissions |

### Metal3-io

Metal3 project's own organization.

#### baremetal-operator

<https://github.com/metal3-io/baremetal-operator>

Generic score: `5.6`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | CodeOwner review not required in "main", Required reviewers is 0 in "main" |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Pinned-Dependencies | 5/10 | Not all deps (Github actions, Dockerfiles) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Token-Permissions | 0/10 | Github workflows using token with too many permissions |

#### cluster-api-provider-metal3

<https://github.com/metal3-io/cluster-api-provider-metal3>

Generic score: `5.2`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | CodeOwner review not required in "main" or "release-0.3", Required reviewers is 0 in "main" and "release-0.3" |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Pinned-Dependencies | 5/10 | Not all deps (Github actions, Dockerfiles) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |
| Signed-Releases | 0/10 | No signatures |
| Token-Permissions | 0/10 | Github workflows using token with too many permissions |

#### hardware-classification-controller

<https://github.com/metal3-io/hardware-classification-controller>

Generic score: `6.0`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | CodeOwner review not required in "main", Required reviewers is 0 in "main" |
| CI-Tests | 9/10 | Only 11/12 were tested by CI, verify |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Maintained | 3/10 | Only 2 commits in 90 days |
| Pinned-Dependencies | 7/10 | Not all deps (Dockerfiles, images) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

#### ip-address-manager

<https://github.com/metal3-io/ip-address-manager>

Generic score: `5.2`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | CodeOwner review not required in "main" or "release-0.3", Required reviewers is 0 in "main" and "release-0.3" |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Pinned-Dependencies | 5/10 | Not all deps (Github actions, Dockerfiles) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |
| Signed-Releases | 0/10 | No signatures |
| Token-Permissions | 0/10 | Github workflows using token with too many permissions |

#### ironic-agent-image

<https://github.com/metal3-io/ironic-agent-image>

Generic score: `5.1`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 0/10 | Branch protection not enabled |
| CI-Tests | 0/10 | 0/15 of merged commits tested by CI |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Maintained | 2/10 | Only 3 commits in 90 days, 0 issue activity |
| Pinned-Dependencies | 2/10 | Not all deps (Github actions, Dockerfiles, pip installs) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

#### ironic-client

<https://github.com/metal3-io/ironic-client>

Generic score: `5.4`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 6/10 | No status checks, only 1 reviewer, no codeowner review required |
| CI-Tests | 0/10 | 0/11 of merged commits tested by CI |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Code-Review | 6/10 | Only 10/16 changesets code reviewed |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Maintained | 3/10 | Only 3 commits in 90 days, 1 issue activity |
| Pinned-Dependencies | 2/10 | Not all deps (Github actions, Dockerfiles, pip installs) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

#### ironic-image

<https://github.com/metal3-io/ironic-image>

Generic score: `6.3`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | 0 reviewer, no codeowner review required |
| CI-Tests | 9/10 | 14/15 of merged commits tested by CI |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Pinned-Dependencies | 2/10 | Not all deps (Github actions, Dockerfiles, pip installs) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

#### ironic-ipa-downloader

<https://github.com/metal3-io/ironic-ipa-downloader>

Generic score: `6.0`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | 0 reviewer, no codeowner review required |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Maintained | 4/10 | Only 4 commits in 90 days, 0 issue activity |
| Pinned-Dependencies | 7/10 | Not all deps (Dockerfiles) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

#### metal3-dev-env

<https://github.com/metal3-io/metal3-dev-env>

Generic score: `7.1`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 3/10 | 0 reviewer, no codeowner review required |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Fuzzing | 0/10 | No fuzzing |
| Pinned-Dependencies | 4/10 | Not all deps (Dockerfiles, Github actions, pip, downloads) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |
| Token-Permissions | 9/10 | Github workflows using token with too many permissions |

#### metal3-docs

<https://github.com/metal3-io/metal3-docs>

Generic score: `6.3`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 0/10 | Branch protection not enabled |
| CI-Tests | 8/10 | 13/16 of merged commits tested by CI |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Pinned-Dependencies | 7/10 | Not all deps (Dockerfiles) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

#### metal3-io.github.io

<https://github.com/metal3-io/metal3-io.github.io>

Generic score: `5.0`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 0/10 | No branch protection for 'source' |
| CI-Tests | 3/10 | 5/14 of merged commits tested by CI |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Code-Review | 8/10 | Only 13/15 changesets code reviewed |
| Fuzzing | 0/10 | No fuzzing |
| License | 0/10 | No license file found |
| Maintained | 1/10 | Only 2 commits in 90 days, 0 issue activity |
| Pinned-Dependencies | 7/10 | Not all deps (Github actions) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |
| Token-Permissions | 0/10 | No top-level permissions defined |

#### project-infra

<https://github.com/metal3-io/project-infra>

Generic score: `5.5`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 0/10 | No branch protection for 'main' |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Pinned-Dependencies | 7/10 | Not all deps (Github actions) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |
| Token-Permissions | 0/10 | No top-level permissions defined |

### Nordix

Metal3 support projects hosted under `Nordix` organization.

#### metal3-clusterapi-docs

<https://github.com/Nordix/metal3-clusterapi-docs>

Generic score: `6.0`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 1/10 | Force pushes enabled, allow deletion enabled, admin bypass, no status checks, reviewers only 1, codeowner review not required, stale review dismissal enabled |
| CI-Tests | 0/10 | 0/17 of merged commits tested by CI |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| License | 0/10 | No license file found |
| Maintained | 6/10 | Only 8 commits in 90 days, 0 issue activity |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

#### metal3-dev-tools

<https://github.com/Nordix/metal3-dev-tools>

Generic score: `7.1`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 2/10 | Admin bypass, no status checks, 1 reviewer, no codeowner review required, stale review dismiss enabled |
| CI-Tests | 1/10 | 3/29 of merged commits tested by CI |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Fuzzing | 0/10 | No fuzzing |
| Pinned-Dependencies | RESCAN | Not all deps (Dockerfiles, Github actions, pip, downloads) are pinned by hash |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

### OpenStack

OpenStack hosts two crucial projects related to IPA, ironic-python-agent.

#### ironic-python-agent-builder

<https://github.com/openstack/ironic-python-agent-builder>

Generic score: `4.8`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 0/10 | No branch protection for any branch |
| CI-Tests | - | No PRs found |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Code-Review | 0/10 | 0/30 changesets code reviewed |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| Maintained | 1/10 | Only 2 commits in 90 days, 0 issue activity |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |

#### ironic-python-agent

<https://github.com/openstack/ironic-python-agent>

Generic score: `5.6`

| Check | Score | Finding |
|---|---|---|
| Branch-Protection | 0/10 | No branch protection for any branch |
| CI-Tests | - | No PRs found |
| CII-Best-Practices | 0/10 | Missing self-assessment + badge in README.md |
| Code-Review | 0/10 | 0/30 changesets code reviewed |
| Dependency-Update-Tool | 0/10 | Configuration not found |
| Fuzzing | 0/10 | No fuzzing |
| SAST | 0/10 | No SAST checks |
| Security-Policy | 0/10 | Security policy file not detected |
