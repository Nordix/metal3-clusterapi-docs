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

def query_k8s_obj(namespace, obj_type, obj_name):
    try:
        rsp = subprocess.check_output(["kubectl", "-n", namespace, "get", obj_type, obj_name, "-o", "json"])
        return json.loads(rsp.decode())
    except Exception:
        return {}

def create_node(node):
    uuid = node["uuid"]
    name = node["name"]
    namespace = "metal3"
    port = 8001 + (int(name.strip("fake")) - 1) % int(os.environ.get("N_SUSHY", 10))
    random_mac = generate_random_mac()
    manifest = f"""---
apiVersion: v1
kind: Secret
metadata:
  name: {name}-bmc-secret
  namespace: {namespace}
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
  namespace: {namespace}
spec:
  online: true
  bmc:
    address: redfish+http://192.168.111.1:{port}/redfish/v1/Systems/{uuid}
    credentialsName: {name}-bmc-secret
  bootMACAddress: {random_mac}
  bootMode: legacy
"""
    manifest_file = f"bmc-{name}.yaml"
    with open(manifest_file, "w") as f:
        f.write(manifest)
    print(f"Generated manifest for node {name}")
    subprocess.run(
            ["kubectl", "apply", "-f", manifest_file],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL)
    time.sleep(5)
    while True:
        status = query_k8s_obj(namespace, "bmh", name)
        if status == {}:
            time.sleep(5)
            continue
        state = status.get("status", {}).get("provisioning", {}).get("state")
        if state == "available":
            print(f"BMH {name} provisioned")
            return
        time.sleep(5)

if __name__ == "__main__":
    with Pool(30) as p:
        conductors = p.map(create_node, nodes)
