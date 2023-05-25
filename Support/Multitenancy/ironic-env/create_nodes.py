import json
import subprocess
from multiprocessing import Pool

with open("nodes.json") as f:
    nodes = json.load(f)

def create_node(node):
    uuid = node["uuid"]
    name = node["name"]
    subprocess.run(["baremetal", "node", "create", "--driver", "redfish", "--driver-info",
    "redfish_address=http://192.168.111.1:8000", "--driver-info",
    f"redfish_system_id=/redfish/v1/Systems/{uuid}", "--driver-info",
    "redfish_username=admin", "--driver-info", "redfish_password=password",
                    "--uuid", uuid, "--name", name])
    print(f"Created node {name} on ironic")

with Pool(100) as p:
    conductors = p.map(create_node, nodes)
