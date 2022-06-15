# New Ironic deployment investigation
In Metal3, ironic is deployed in a container image, the repo of which can be found at: https://github.com/metal3-io/ironic-image. This document provides some details about the ports that an ironic pod in Metal3 cluster can open and the interaction between them. The commit used for this investigation of ironic-image repo is **09ad5a22056a4334db76fd10b8def660936d1a03**.

There are 7 containers in an ironic pod:
- ironic: This container has one ironic process. This process runs in the combined mode of ironic, as opposed to the separated mode where api and conductor parts run in two different processes.
	+ Port 6388: Listens to api requests. These requests are handled by api part of ironic. In fact, the traffic coming to this port is mostly from the reverse proxy ironic-httpd.
            IP: 127.0.0.1 - Interface: Loop back
- ironic-inspector: No change
	+ Port 5049: Listens to inspector requests. The traffic coming to this port is mostly from the reverse proxy ironic-httpd.
            IP: 127.0.0.1 - Interface: Loop back
- ironic-httpd:
	+ Port 6385: Any traffic coming to this port is forwarded to port 6388 of ironic container.
	+ Port 5050: Any traffic coming to this port is forwarded to port 5049 of ironic-inspector container.
	+ Port 6180: Allows downloading IPA image
            IP (3 ports above): 0.0.0.0/0 - All interfaces
- mariadb: This database will soon be replaced by SQLite by default.
	+ Port 3306: Database port. Ironic connects to this port to read and write node data.
            IP: 0.0.0.0/0 - all interfaces
- ironic-keepalived: No change
- ironic-dnsmasq: No change
	+ Port 67: bootstrap server. For PXE boot
            IP: 0.0.0.0/0 - all interfaces
	+ Port 69: TFTP
            IP: 172.22.0.1-2 - ironicendpoint
- ironic-log-watch: No change

Note: In order to prevent ports to open on all interfaces, set LISTEN_ALL_INTERFACES = false
