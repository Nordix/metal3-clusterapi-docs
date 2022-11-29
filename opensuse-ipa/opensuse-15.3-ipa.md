# Process to build OpenSuSe Leap 15.3 based IPA image

## Current situation 12.08.2021

CCD request was to check whether it is possible to speed up the inspection process when using the OpenSUSE based
IPA images. The idea was that using IPA on OpenSUSE Leap 15.3 might be faster than the currently used 15.1 .

OpenSuSe Leap 15.3 didn't receive an official OpenStack specific base image that
could be used as a base for building OpenSuse 15.3 based IPA image. In order to build a 15.3 based image
the diskimage_builder used in the build process had to be modified to support `qcow2` disk images.

The build process was tested by utilizing the following [repository](https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.3/images/) .

## Setup Environment

Pyhon `virtualenv` and `pip` can be installed using the following command:

```bash
       sudo apt install python3-pip
       sudo apt install python3-virtualenv
       sudo apt install qemu-utils
```

First create a separate directory and then create the virtual env inside and activate:

```bash
       mkdir dib
       cd dib
       virtualenv myenv-opensuse
       source myenv-opensuse/bin/activate
```

Then update PIP

```bash
        python3 -m pip install -U pip
```

And install

```bash
   python3 -m pip install git+<https://opendev.org/openstack/diskimage-builder>
```

Install IPA builder inside the virtualenv.

```bash
      python3 -m pip install ironic-python-agent-builder
```

**The build process also requires the presence of the `qemu-img` tool.**

## Edit the disk image builder image download script

The disk image builder will be installed to the virtual environment and the
script responsible for downloading OpenSUSE base image will be located on the following path:

`<path_to_virtualenv>/lib/<curent_python_version>/site-packages/diskimage_builder/elements/opensuse/root.d 10-opensuse-cloud-image`

### Step 1

Delete the last line that looks like this:

```bash
 # Extract the base image (use --numeric-owner to avoid UID/GID mismatch between
 # image tarball and host OS)
 sudo tar -C $TARGET_ROOT --numeric-owner -xf $CACHED_FILE
```

### Step 2

Insert the following commands at the end of the file:

```bash
    # Remove the mount to avoid using old mount point
 SUSE_MOUNT_PATH=${SUSE_MOUNT_PATH:-/mnt/suse}
 if mount | grep "${SUSE_MOUNT_PATH}"; then
  sudo umount "${SUSE_MOUNT_PATH}"
 fi
 # Optional cleanup raw disk image cleanup step, it can be removed
 if ls "${DIB_IMAGE_CACHE}/${BASE_IMAGE_FILE%.*}"; then
  sudo  rm "${DIB_IMAGE_CACHE}/${BASE_IMAGE_FILE%.*}"
 fi
 # Convert to mountable disk image format
 sudo qemu-img convert -f qcow2 -O raw "${DIB_IMAGE_CACHE}/${BASE_IMAGE_FILE}" "${DIB_IMAGE_CACHE}/${BASE_IMAGE_FILE%.*}"
 # Query disk characteristics
 UNIT_SIZE=$(fdisk -l  "${DIB_IMAGE_CACHE}/${BASE_IMAGE_FILE%.*}" | grep -o "[[:digit:]] \* [[:digit:]]*" | sed 's/[[:digit:]]* \* //')
 START_ADDRESS=$(fdisk -l -o Start,Type "${DIB_IMAGE_CACHE}/${BASE_IMAGE_FILE%.*}" | grep "Linux filesystem" | sed  -e 's/[A-Za-z]//g; s/[[:space:]]//g')
 OFFSET=$((START_ADDRESS*UNIT_SIZE))
 SECTORS_NUM=$(fdisk -l -o Sectors,Type  "${DIB_IMAGE_CACHE}/${BASE_IMAGE_FILE%.*}" | grep "Linux filesystem" | sed  -e 's/[A-Za-z]//g; s/[[:space:]]//g')
 SIZE_LIMIT=$((SECTORS_NUM*UNIT_SIZE))
 # Mount
 sudo mount -o offset=$OFFSET,sizelimit=$SIZE_LIMIT "${DIB_IMAGE_CACHE}/${BASE_IMAGE_FILE%.*}" "${SUSE_MOUNT_PATH}"
 # Copy root filesystem to be used by the image builder
 sudo cp -ar "${SUSE_MOUNT_PATH}/." "${TARGET_ROOT}/."
```

The first step is to remove left over mount if it is present and remove the previously built disk image. The disk image removal is optional as
it can be overwritten.

Then the newly downloaded (or already cached) qcow2 disk image has to be converted to a mountable raw disk image format.

As the third step the newly created raw disk image characteristics will be colleted to variables.

The raw disk image will be mounted to /mnt/suse by default but it can be configured by putting here any arbitrary mount path.

The last command will simply copy content of the mounted rootfs to the designated location thus it will be included in the image build.

## Additional modification in case of the build wouldn't succeed

**Optional**:
If there would be any error during zypper upgrade, need to make small changes in disk image builder scripts.
First add an option for zypper upgrade which is opensuse related, otherwise  the script cannot proceed the building process.

The script can be found in: `<path_to_virtualenv>/lib/<curent_python_version>/site-packages/diskimage_builder/elements/zypper/bin/install-packages`

Content of line no.50 is doing the distribution related upgrade for openSuse, which was failing without resolution.

```bash
 -u) run_zypper dist-upgrade --no-recommends ; exit 0;;
```

Updated content:

```bash
 -u) run_zypper dist-upgrade --no-recommends --force-resolution ; exit 0;;
```

**Other potential issue**:
The following script is from disk image builder and it is necessary to change because of invalid command “SuSe-release” which is deprecated in older versions of openSuse.
The script is located in: `<path_to_virtualenv>/lib/<curent_python_version>/site-packages/diskimage_builder/lib/img-functions` and edit the line no. 213.

Original content of the line is:

```bash
 elif [ -f $TARGET_ROOT/etc/SuSe-release ]; then
```

Suse-release is already deprecated in openSuse 13 release and not a valid directory. It was unable to fetch the version of the operating system.
The newest version of this directory is os-release. It solves the issue with the OS version.

The content of line no. 213 has to be modified to look like this:

```bash
 elif [ -f $TARGET_ROOT/etc/os-release ]; then
```

## Execute the image building process

After all of the modifications have been implement make sure that the virtual environment is
still active and execute the following command inside the virtual environment:

```bash
    DIB_CLOUD_IMAGES=https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.3/images BASE_IMAGE_FILE=openSUSE-Leap-15.3.x86_64-NoCloud.qcow2 ironic-python-agent-builder -o opensuse-15.3-ipa opensuse -v
```

## Conclusion

The image build was successful and the the OpenSUSE Leap 15.3 based IPA image booted successfully and started the inspection process.

### The inspection still takes to much time

There is still a problem with how much time it takes to run the actual inspection when using the OpenSUSE 15.3 based IPA image because during the development environment setup `IPA inspection timed out` **so the timeout issue still needs to be resolved.**

### Further image customization is required

The additional issue is that the current 15.3 build was based on the "openSUSE-Leap-15.3.x86_64-NoCloud.qcow2" thus it lacks any customization that would help with debugging and monitoring the IPA inspection process as e.g. IPA is not logging it's status to serial consol by default so during the build process the image has to be further customized to better support IPA usage.
