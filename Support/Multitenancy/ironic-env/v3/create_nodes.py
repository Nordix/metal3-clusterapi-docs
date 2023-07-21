import json
import subprocess
import time
import random
import os
from multiprocessing import Pool

with open("nodes.json") as f:
    nodes = json.load(f)

def generate_random_mac():
    # Generate a random MAC address
    mac = [random.randint(0x00, 0xff) for _ in range(6)]
    # Set the locally administered address bit (2nd least significant bit of the 1st byte) to 1
    mac[0] |= 0x02
    # Format the MAC address
    mac_address = ':'.join('%02x' % b for b in mac)
    return mac_address

def create_node(node):
    uuid = node["uuid"]
    name = node["name"]
    port = 8001 + (int(name.strip("fake")) - 1) % int(os.environ.get("N_SUSHY", 10))
    # subprocess.run(["baremetal", "node", "create", "--driver", "redfish", "--driver-info",
    # f"redfish_address=http://192.168.111.1:{port}", "--driver-info",
    # f"redfish_system_id=/redfish/v1/Systems/{uuid}", "--driver-info",
    # "redfish_username=admin", "--driver-info", "redfish_password=password",
    #                 "--uuid", uuid, "--name", name], stdout=subprocess.DEVNULL)
    random_mac = generate_random_mac()
    manifest = f"""
---
apiVersion: v1
kind: Secret
metadata:
  name: {name}-bmc-secret
  labels:
      environment.metal3.io: baremetal
type: Opaque
data:
  username: YWRtaW4=
  password: cGFzc3dvcmQ=
---
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: {name}
  uid: {uuid}
spec:
  online: true
  bmc:
    address: redfish+http://192.168.111.1:{port}/redfish/v1/Systems/{uuid}
    credentialsName: {name}-bmc-secret
  bootMACAddress: {random_mac}
  bootMode: legacy
"""
    with open(f"bmc-{name}.yaml", "w") as f:
        f.write(manifest)
    # subprocess.run(["kubectl", "apply", "-f", f"bmc-{name}.yaml"])
    print(f"Created node {name} on ironic")

if __name__ == "__main__":
    with Pool(100) as p:
        conductors = p.map(create_node, nodes)
