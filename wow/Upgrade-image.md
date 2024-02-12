# Metal3 node and openstack images upgrading

## 1. Download the vanilla image

- **Ubuntu**

Download the target raw version from [ubuntu.com](https://cloud-images.ubuntu.com/)
then convert it to `qcow2`

```console
qemu-img convert -O qcow2 ubuntu-22.04-server-cloudimg-amd64.img ubuntu-22.04-server-cloudimg-amd64.qcow2
```

- **Centos**

Download the target qcow2 version directly from
[centos.org](https://cloud.centos.org/centos/9-stream/x86_64/images/)

## 2. Upload the qcow2 to both regions in citycloud

The region target can be specified in the openstack rc-file, download
and source the rc-file then run

```sh
openstack image create --disk-format qcow2 --container-format bare \
    --private --file ./Centos-7-9-22.qcow2 CentOS-Stream-9-20220829
```

## 3. Update the source image name in the dev-tools

Create a PR to update the source image name `SOURCE_IMAGE_NAME` that
will be used when running the image building job, [for example](
https://github.com/Nordix/metal3-dev-tools/pull/592/files).

## 4. Trigger image building job

Once the dev-tools PR get merged, the image building job will be
triggered automatically and build node images with the default
kubernetes version and the openstack images in the different regions,
but you still need to re-trigger the job manually from jenkins to build
the node images with old kubernetes versions needed. (Login to Jenkins
go to openstack_node_image_building Job and click "Build with
Parameters" after that set the kubernetes version needed).

The main tests usually use two node images with different kubernetes
minor versions needed when testing kubernetes upgrade. check
`KUBERNETES_VERSION` and `UPGRADED_K8S_VERSION` in dev-env.

The older CAPM3 releases might still need different kubernetes versions
for their tests!

## 5. Update dev-env and CAPM3

After building all the necessary images and uploading them, we need to
update the images name and location in dev-env and CAPM3 repos. Example
PRs:
[dev-env uplift](https://github.com/metal3-io/metal3-dev-env/pull/1069/files),
[CAPM3 uplift](https://github.com/metal3-io/cluster-api-provider-metal3/pull/712/files).
Please to be noted, we might need to back port the updates to the old
releases in CAPM3.

For PR testing, it is preferred to start with dev-env since the CAPM3 PR
depends on dev-env but both PR need to go in together since after
changing dev-env CAPM3 might be failing.
