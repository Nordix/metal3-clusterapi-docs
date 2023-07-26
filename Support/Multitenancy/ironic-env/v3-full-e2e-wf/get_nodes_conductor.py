import json
import subprocess
from multiprocessing import Pool

with open("nodes.json") as f:
    nodes = json.load(f)

node_conductors = {}

def get_conductor(node):
    name = node["name"]
    r = subprocess.check_output(["baremetal", "node", "show", name, "-f", "json"])
    content = json.loads(r)
    conductor = content.get("conductor")
    return conductor

with Pool(100) as p:
    conductors = p.map(get_conductor, nodes)

for i in range(len(nodes)):
    print(f"{nodes[i].name}: {conductors[i]}")

