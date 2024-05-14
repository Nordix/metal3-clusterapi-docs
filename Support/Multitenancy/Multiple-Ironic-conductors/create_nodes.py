import json
import subprocess
import time
import random
import os
from multiprocessing import Pool

N_SUSHY_CONTAINERS=int(os.environ.get("N_SUSHY", 2))

with open("nodes.json") as f:
    nodes = json.load(f)

def query_k8s_obj(namespace, obj_type, obj_name):
    try:
        rsp = subprocess.check_output(["kubectl", "-n", namespace, "get", obj_type, obj_name, "-o", "json"])
        return json.loads(rsp.decode())
    except Exception:
        return {}

def create_node(node):
    uuid = node["uuid"]
    name = node["name"]
    namespace = "default"
    port = 8001 + ((int(name.strip("test")) - 1) % N_SUSHY_CONTAINERS)
    random_mac = node["nics"][0]["mac"]
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
    address: redfish+http://192.168.222.200:{port}/redfish/v1/Systems/{uuid}
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

def wait_node(node):
    name = node["name"]
    namespace = "default"
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
