import json
import subprocess

info = subprocess.check_output(["baremetal", "node", "list", "-f", "json", "--noindent"])
nodes = json.loads(info.decode())

# start = int(sys.argv[1])
# end = int(sys.argv[2])

# display_nodes = [node for node in nodes if int(node["Name"].strip("fake")) >= start and int(node["Name"].strip("fake")) <= end]
display_nodes = [node for node in nodes if node["Provisioning State"] not in ["enroll", "manageable", "inspect failed"]]

inspected_nodes = [node for node in nodes if node["Provisioning State"] == "manageable"]
failed_nodes = [node for node in nodes if node["Provisioning State"] == "inspect failed"]

for node in display_nodes:
    print(f"{node['Name']}: {node['Provisioning State']}")

print(f"Inspected {len(inspected_nodes)}/{len(nodes)} nodes")
print(f"Failed {len(failed_nodes)}/{len(nodes)} nodes")
