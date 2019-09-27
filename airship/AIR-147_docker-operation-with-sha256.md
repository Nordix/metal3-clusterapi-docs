[main page](README.md)|[experiments](experiments/AIR-147_.md)

---

# Verify that sha256 can be used to do docker operations

**key objectives**: Investigate if digest (i.e. sha256 hash) can be used to perform docker operations.

Jira Issue:
- [Docker operations with sha256](https://airship.atlassian.net/browse/AIR-147)


When you build docker image locally, a new image contains unique id - i.e., sha265 hash, which is stored in `"Id"` field as shown in the following example:

```bash
root@infra:~# docker inspect 9cfd3f2209d4

[
    {
        "Id": "sha256:9cfd3f2209d47b7199afe9ac6538de9bdaf7f5c3e0ee59c1f72b306c73576a1a",
        "RepoTags": [
            "feruzjon/test_image:v1"
        ],
        "RepoDigests": [],
        "Parent": "sha256:6a3d9aac839a5fe40c245492747f5afe2dd2b2dedf10d26acaa8636eaba3b0a6",
        .
        .
        .
```

This `"Id"` can be used to perform docker operations unless image is locally present. However, `"RepoDigests"` field is still empty since the image is not pushed to registry yet.
We can check that any locally built image has no sha256 hash in the `"RepoDigests"` field before it is pushed:

```bash
root@infra:~# docker images --digests


REPOSITORY            TAG                 DIGEST                                                                    IMAGE ID            CREATED             SIZE
feruzjon/test_image   v1                  <none>                                                                    9cfd3f2209d4        20 seconds ago      203MB
```


After the local image is pushed to Docker container registry, another new unique sha256 hash is generated and added to `"RepoDigests"` field as shown in the following example:

```bash
root@infra:~# docker inspect f4c5014bf5bc

[
    {
        "Id": "sha256:9cfd3f2209d47b7199afe9ac6538de9bdaf7f5c3e0ee59c1f72b306c73576a1a",
        "RepoTags": [
            "feruzjon/test_image:v1"
        ],
        "RepoDigests": [
            "feruzjon/test_image@sha256:af3c4136783600d18b66cabba60f00caf56cca5142dec2f87dd30f69dc44e6ce"
        ],
        "Parent": "sha256:6a3d9aac839a5fe40c245492747f5afe2dd2b2dedf10d26acaa8636eaba3b0a6",
        .
        .
        .
```
sha256 from "RepoDigests" field can be used for only pulling the image as follows:
```bash
root@infra:~# docker pull feruzjon/test_image@sha256:af3c4136783600d18b66cabba60f00caf56cca5142dec2f87dd30f69dc44e6ce
```

We can check once again if the `"RepoDigests"` field contains image digest:
```bash
root@infra:~# docker images --digests


REPOSITORY            TAG                 DIGEST                                                                    IMAGE ID            CREATED             SIZE
feruzjon/test_image   v1                  sha256:af3c4136783600d18b66cabba60f00caf56cca5142dec2f87dd30f69dc44e6ce   9cfd3f2209d4        3 minutes ago       203MB

```

## Key observations

1. sha256 stored in the `"Id"` field can be used to perform docker operations except pulling.
2. sha256 from `"RepoDigests"` field can be publicly used to pull docker images.
3. If the image is updated but pushed with exactly the same `"name:tag"`, previous image will not be deleted but rather
tagged as `<none>:<none>`. As such, if one wants to pull previous image (which is tagged as `<none>:<none>` currently),
digest from `"RepoDigests"` field can be used to pull it.
