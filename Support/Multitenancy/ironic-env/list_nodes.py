import json
import subprocess
import sys

info = subprocess.check_output(["baremetal", "node", "list", "-f", "json", "--noindent"])
nodes = json.loads(info.decode())

start = int(sys.argv[1])
end = int(sys.argv[2])

display_nodes = [node for node in nodes if int(node["Name"].strip("fake")) >= start and int(node["Name"].strip("fake")) <= end]

for node in display_nodes:
    print(f"{node['Name']}: {node['Provisioning State']}")
