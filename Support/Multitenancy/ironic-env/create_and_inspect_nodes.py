import json
import subprocess
import time
import os
from multiprocessing import Pool

with open("nodes.json") as f:
    nodes = json.load(f)

def create_node(node):
    uuid = node["uuid"]
    name = node["name"]
    port = 8001 + (int(name.strip("fake")) - 1) % int(os.environ.get("N_SUSHY", 10))
    subprocess.run(["baremetal", "node", "create", "--driver", "redfish", "--driver-info",
    f"redfish_address=http://192.168.111.1:{port}", "--driver-info",
    f"redfish_system_id=/redfish/v1/Systems/{uuid}", "--driver-info",
    "redfish_username=admin", "--driver-info", "redfish_password=password",
                    "--uuid", uuid, "--name", name], stdout=subprocess.DEVNULL)
    print(f"Created node {name} on ironic")

def check_info(node_name):
    info = subprocess.check_output(["baremetal", "node", "show", node_name, "-f", "json"])
    return json.loads(info)

def inspect_node(node):
    name = node["name"]
    print(f"Inspecting node {name}")
    subprocess.run(["baremetal", "node", "manage", name])
    while True:
        time.sleep(2)
        info = check_info(name)
        if info["provision_state"] == "manageable":
            break
        elif info["provision_state"] not in ["enroll", "verifying"]:
            raise ValueError(f"Cannot enroll node {name}")
    subprocess.run(["baremetal", "node", "inspect", name])
    while True:
        time.sleep(2)
        info = check_info(name)
        if info["provision_state"] == "manageable":
            print(f"Node {name} was inspected at {info['inspection_finished_at']}")
            return
        elif info["provision_state"] == "inspect failed":
            print(f"Node {name} was failed in inspection")
            return

if __name__ == "__main__":
    with Pool(100) as p:
        conductors = p.map(create_node, nodes)

    print("Created all nodes")

    with Pool(30) as p:
        p.map(inspect_node, nodes)
