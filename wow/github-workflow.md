# Github Workflow

## Overview

The workflow is based on the understanding that:

- A project is forked from Open Source project to nordix
- A local copy is cloned from nordix

We refer to the Open Source project repo as `upstream`, `upstream/main`
and to the forked repo in the Nordix organization as `origin`,
`origin/main`

Main branch is called `main`, containing the latest stable release.

Feature development and bug fixing are done in topic branches, branched
of `main` branch. Upon completion and code review, topic branch is
merged into `upstream` branch.

## Branches

### Topic branches (features and bug fixes)

Topic branches need to be branched off `main` and named
`type/name-username`, where  type is `feature` or `fix` and `username`
the Github username or the name of the person creating the branch, to
mark ownership of the branch.

For example, a branch name for a feature called `Add support for
policies` by user xyz would be `feature/policy-support-xyz` or similar,
where a `User cannot login` bug would be `fix/user-cannot-login-xyz` or
similar.

If applicable, branch name should also contain Github Issue ID, for
example `fix/13-userr-cannot-login-xyz`.

## Commit Message

Commit message should be formatted as following.

```sh
Short (50 chars max or as subjected by open source repo practise) summary

More detailed explainatory text, if necessary. Wrap it to about 72
characters or so. Write your commit message in the imperative: "Fix bug"
and not "Fixed bug" or "Fixes bug".

Signed-off-by: My Name <my.name@est.tech>
Co-authored-by: My Colleague <my.colleague@est.tech>
```

If your commit includes contributions from someone else, add this person as
co-author by adding the Co-authored-by trailer at the end of your commit.

Note that the email address might be protected by Github, then you need to
use the address provided by Github.

## Git workflow for a Github repo through Nordix

### 1. Create a topic branch

Create and checkout local branch where you will do your work.

`git checkout -b <topic-branch> origin/main`

Make sure to have the latest code from the upstream repository

```sh
git fetch upstream
git rebase upstream/main
```

When pushing the branch for the first time, ensure correct tracking is set up:

`git push -u origin <topic-branch>`

### 2. Keep topic branch up-to-date

When changes have been pushed to `main` branch, ensure your topic branch is up-to-date.

```sh
git fetch upstream
git checkout <topic-branch>
git rebase upstream/main
```

<!-- markdownlint-disable MD026 -->
### 3. Code, test ....
<!-- markdownlint-enable MD026 -->

Do your magic :)

### 4. Commit the changes

Changes should be grouped into logical commits, Refer to above [commit
message](#commit-message) for details.

```sh
git add -p # only for existing files
git add <file> # when new file added
git commit -S
```

### 5. Push the changes

Rebase your changes on the upstream main to make sure
to have the latest commits in

```sh
git fetch upstream
git rebase upstream/main
```

Changes should be pushed to a correct origin branch:

`git push -u origin <topic-branch>`

You may need to force push your topic-branch, however this MUST be
avoided as much as possible in this stage

`git push -fu origin <topic-branch>`

### 8. Squash your commits

Once the pull request is approved, at this stage you should squash your commits,
making logical units, for example introducing a single feature, squashing all
the small fixes coming from the code review.

```sh
git fetch upstream
git rebase -i upstream/main
```

### 9. Open an `Upstream` Pull Request

When the local code review is done and commit gets 2 thumbs up(+2), an
upstream pull request is made from same topic-branch to the open source
project for code review.

Before opening it, **please ensure your branch is up-to-date with
`main`** branch and your commits are properly formatted.

```sh
git fetch upstream
git checkout <topic-branch>
git rebase upstream/main
git push -u origin <topic-branch>
```

### 10. Upstream Code review

Upstream Code review is done based on the practises defined by the open source project.

Nevertheless the assumption is the pull request is ready for merge to
the upstream when the reviewrs has given 1 or 2 thumbs up (+1 or +2).

### 11. Merging the code into upstream

Pull request author can merge the code after PR has thumbs up or practises
defined by the open source project. After a successful code review, `topic`
branch is merged to `upstream`. Merging then depends on the project and is
usually done through the web interface. Once merged, you can

```sh
git fetch
git checkout <topic-branch>
```

### 12. Delete the branch when needed

To avoid leaving unneeded branches in the repository, delete your branch if you
don't use it anymore.

Remove the topic branch remotely only

```sh
git push origin :<topic-branch>
```

Remove the topic branch locally only

```bash
git branch -d <topic-branch>
```

## git workflow for a Nordix github repo

It is exactly the same process except that steps 9. 10. and 11. do not happen.
Instead the code is merged with the internal pull request.

## How to backport

Sometimes you may need to backport a commit (e.g. bug fix) from a main
branch into a stable release branch. This involves a couple of steps as
described below. In this example, we will use `release-0.3` as the
stable branch in to which we will backport a specific commit from the
`main` branch.

Create and checkout to a new branch (e.g. `backport_commit_x`) based on
the stable branch (e.g. `release-0.3`)

```bash
git checkout -b backport_commit_x origin/release-0.3
```

In order to cherry-pick a specific commit(s) you want, you will need to
identify the commit hash(es).

```bash
git log --oneline --no-merges ..main
```

prints out all the commits in the `main` branch which aren't in the
`release-0.3` branch in a below provided format:

```text
34a036b73 random1
d2ff718f9 random2
d83cb0e4b random3
d589bcfc2 random4
b9a16e24e random5
eface850b random6
```

Here you need to take a copy of a SHA (e.g. `eface850b` for random6) of
the specific commit that you want to backport into the `release-0.3`
branch.

Once you know the SHA of the commit, you can cherry-pick that commit.

```bash
git cherry-pick -x eface850b
```

If you have conflicts you will need to fix them first and then run the
below commands before you push.

```bash
git add .
git cherry-pick --continue
```

If you don't have conflicts or you have already fixed them, then go
ahead and push your commit.

```bash
git push origin backport_commit_x
```

During the PR submission on the Github UI, make sure that you have
selected the right target branch, which in our case is `release-0.3`
branch.
