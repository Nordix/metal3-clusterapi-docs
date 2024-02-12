# Ironic Python Agent archive unpacking

IPA archive consists of two files:

- `ironic-python-agent.initramfs`
- `ironic-python-agent.kernel`

The kernel is regular Linux executable `bzImage`, and `initramfs` is holding
the OS. Sometimes we need to peek inside the image for debug purposes, and
in those cases it is much easier to just unpack it, than to boot it for
inspection.

## Usage

Run the script with IPA image as first argument, and non-existing output
directory as second argument.

Script needs `tar`, `gunzip` and `cpio` to work, and it checks for those.
If they're missing, install them via your package manager.

```bash
./unpack-ipa-archive.sh <ironic-agent-image.tar> <output_dir>
```

The script creates output directory, and within the output directory it'll
create `filesystem` directory, where the `initramfs` is unpacked.
You can then do the same for another IPA archive for another output dir,
and then use your favorite tool to compare the directories.
