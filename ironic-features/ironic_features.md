# New ironic features 2021.09.29 - 2022.03.15

## Branching

* **CCD current**: b33783281b14d2c371c4d32d20077489aad2dd78

Commit message:
```
Merge "Use an ImageCache for provided boot/deploy ISO images
```

The following commit hashes point to the commits that were
the last ones before the given release branch was branched off
from the main branch. After these commits the release branch was
created and the implementation of features for the release branch
was stopped.

* **19.0**: cdc3b9538f3e874dc7d76a90b116ecef3a3603c7

Commit message:
```CI: Lower test VM memory by 200MB
We're seeing OOM events in CI, hopefully this helps.
```

* **20.0**: 7ac480412626c38fa3493088dbf49e29303491b6

Commit message:
```Build the new cirros image even when netboot is the default
The standalone job changes boot_option in runtime, so local boot
can be used even when the default boot option is netboot.
```

## New/Changed Configuration options

- (interfaces) The ipxe boot interface is now enabled by default.

- (interfaces)The ipxe boot interface is now enabled and will have priority over pxe by default. If you rely on the default value of the enabled_boot_interfaces
  option to not contain ipxe, you need to set it explicitly.

- (interfaces) The configuration options enabled_power_interfaces and enabled_management_interfaces are now empty by default. If left empty,
  their values will be calculated based on enabled_hardware_types.

- (interfaces/hardware) The Bare Metal service is now capable of calculating the default value for any enabled_***_interfaces based on enabled_hardware_types.

- (PXE/iPXE) Adds a new configuration option [pxe]ipxe_fallback_script which allows iPXE boot to fall back to e.g. ironic-inspector iPXE script.

- (hardware) The redfish hardware type is now enabled by default along with all its supported hardware interfaces.

- (power cycling) Adds new configuration option: [snmp]power_action_delay This option will add a delay in seconds before a snmp power on and after power off.
  Which may be needed with some PDUs as they may not honor toggling a specific power port in rapid succession without a delay. This option may be
  useful if the attached physical machine has a substantial power supply to hold it over in the event of a brownout.

- (boot mode) The default deployment boot mode is now UEFI. Legacy BIOS is still supported, however operators who require BIOS nodes will need to set their nodes,
  or deployment, appropriately

- (boot mode) The default boot mode has been changed and is now UEFI. Operators who were explicitly relying upon BIOS based deployments in the past,
  may wish to consider setting an explicit node level override for the node to only utilize BIOS mode. This can be configured at a conductor level with the [deploy]default_boot_mode.
  Options to set this at a node level can be found in the Ironic Installation guide - Advanced features documentation.

- (iDRAC) Adds support for running management.clear_job_queue, management.reset_idrac and management.known_good_state methods as verify steps on iDRAC hardware type,
  for both idrac-wsman and idrac-redfish interfaces. In order to use this feature, [conductor]verify_step_priority_override needs to be used to set non-zero
  tep priorities for the desired verify steps.

- (GRUB) Manually copying the initial grub config for grub network boot is no longer necessary, as this file is now written to the
  TFTP root directory on conductor startup. A custom template can be used to generate this file with config option [pxe]initial_grub_template.

- (Glance/Swift) The new [glance] swift_account_prefix parameter has been added. This parameter be set according to the
  reseller_prefix parameter in proxy-server.conf of Swift.

## Cache and Node Cleanup

- (image cache) All image caches are now cleaned up periodically, not only when used. Set [conductor]cache_clean_up_interval to tune the interval or disable.

- (idrac-Redfish) Adds support for idrac-redfish RAID and management clean steps to be run without IPA when disabling ramdisk during cleaning.

- (idrac-wsman) Adds support for idrac-wsman RAID, BIOS and management clean steps to be run without IPA when disabling ramdisk during cleaning.

## Images

- ISO images provided via instance_info/boot_iso or instance_info/deploy_iso are now cached in a similar way to normal instance images.
  Set [deploy]iso_master_path to an empty string to disable.

- Introduces a new explicit instance_info parameter image_type, which can be used to distinguish between partition and whole disk images instead of a kernel/ramdisk pair.
  Adding kernel and ramdisk is no longer necessary for partition images if image_type is set to partition and local boot is used.
  The corresponding Image service property is called img_type.

## Single executable Ironic

- Adds a new executable ironic that starts both API and conductor in the same process.
  Calls between the API and conductor instances in the same process are not routed through the RPC.

- Adds a new none RPC transport that can be used together with the combined ironic executable to completely disable the RPC bus.

## Node fast track

- Fast track mode can now be enabled or disabled per node:

```bash
baremetal node set <node> --driver-info fast_track=true
```

## Inspection

- Adds support for verify steps - a mechanism for running optional, actions pre-defined in the driver while the node is in transition from enroll to managable state, prior to inspection.


## IDRAC-REDFISH

- Now the export configuration step from the idrac-redfish management interface does not export iDRAC BMC connection settings to avoid overwriting
  hose in another system when using unmodified configuration mold in import step. For import step it is still possible to add these settings back manually.

- For redfish and idrac-redfish management interface firmware_update clean step adds Swift, HTTP service and file system support to serve and Ironic's HTTP and Swift service to stage files.
  Also adds mandatory parameter checksum for file checksum verification.

Additional features
 -Supports listening on a Unix socket instead of a normal TCP socket. This is useful with an HTTP server such as nginx in proxy mode.

## Upgrade Notes

- Bootloader installation failures are now fatal for whole disk images. Previously these failures were ignored to facilitate backwards
  compatibility with older Ironic Python Agents, however we can now rely on having a sufficiently modern IPA.

- The configuration option [inspector]power_off is now ignored for nodes that have fast-track enabled. These nodes are never powered off.

- Foreign keys are now enabled when SQLite is used as a database.

- For redfish and idrac-redfish management interface firmware_update clean step there is now mandatory checksum parameter necessary. Update existing clean steps to include it,
  otherwise clean step will fail with error "checksum is a required property".


## Known Issues

- When using iDRAC with Swift to stage firmware update files in Management interface firmware_update clean step of redfish or idrac hardware type, the cleaning fails with error
  "An internal error occurred. Unable to complete the specified operation." in iDRAC job. Until this is fixed, use HTTP service to stage firmware files for iDRAC.

## Openstack Storybook issues mentioned in the commits

- [2009807](https://storyboard.openstack.org/#!/story/2009807)  |  [2009863](https://storyboard.openstack.org/#!/story/2009863)
- [2009778](https://storyboard.openstack.org/#!/story/2009778)  |  [2009762](https://storyboard.openstack.org/#!/story/2009762)
- [2008723](https://storyboard.openstack.org/#!/story/2008723)  |  [2009772](https://storyboard.openstack.org/#!/story/2009772)
- [2009704](https://storyboard.openstack.org/#!/story/2009704)  |  [2009774](https://storyboard.openstack.org/#!/story/2009774)
- [2009773](https://storyboard.openstack.org/#!/story/2009773)  |  [2009767](https://storyboard.openstack.org/#!/story/2009767)
- [2009316](https://storyboard.openstack.org/#!/story/2009316)  |  [2009736](https://storyboard.openstack.org/#!/story/2009736)
- [2009676](https://storyboard.openstack.org/#!/story/2009676)  |  [2008167](https://storyboard.openstack.org/#!/story/2008167)
- [2009719](https://storyboard.openstack.org/#!/story/2009719)  |  [2009294](https://storyboard.openstack.org/#!/story/2009294)
- [2009671](https://storyboard.openstack.org/#!/story/2009671)  |  [2009251](https://storyboard.openstack.org/#!/story/2009251)
- [2009203](https://storyboard.openstack.org/#!/story/2009203)  |  [2009278](https://storyboard.openstack.org/#!/story/2009278)
- [2009025](https://storyboard.openstack.org/#!/story/2009025)  |

# ironic inspector features

## Branching

* **10.9**: e3f58e4567194318b039c8d154d03ca2c81b8760

```
Merge "Add support for state selector in the list introspection"
```

* **10.10**: 567b73138d5dae3b7924e98abc946a5f4a90e352

```
Merge "Remove rootwrap rule for dnsmasq systemctl"
```

## New featues

- Supports listening on a Unix socket instead of a normal TCP socket. This is useful with an HTTP server such as nginx in proxy mode.

- Adds support for filter by state in the list introspection API. See story [1625183](https://storyboard.openstack.org/#!/story/1625183)

```
GET /v1/introspection?state=starting,...
````

## Known Issues

- The response headers for empty body HTTP 204 replies, at present, violate RFC7230. This was not intentional, but underlying libraries also make
  inappropriate changes to the headers, which can cause clients to experience odd failures. This is anticipated to be corrected once an underlying
  issue in [eventlet](https://github.com/eventlet/eventlet/issues/746) is resolved.

## Upgrade Notes

- The rootwrap rule to allow restarting the systemd service openstack-ironic-inspector-dnsmasq.service has been removed.
  No known tooling requires this rule since before Train. Any configuration tool which is setting [dnsmasq_pxe_filter]dnsmasq_start_command
  also needs to be writing an appropriate rootwrap.d file, as the inspector devstack plugin does.
