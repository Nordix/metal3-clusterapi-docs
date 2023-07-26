import json
from multiprocessing import Pool
import os
import shutil
import subprocess
import re

__dir__ = os.path.abspath(os.path.dirname(__file__))

subprocess.run([os.path.join(__dir__, "get_ironic_logs.sh")])

logs_dir = os.path.join(__dir__, "logs")
separated_logs_dir = os.path.join(__dir__, "separated_logs")

shutil.rmtree(separated_logs_dir, ignore_errors=True)
os.makedirs(separated_logs_dir)


log_files = os.scandir(logs_dir)
inspector_log = ""
ironic_logs = {}

for f in log_files:
    if "inspector" in f.name:
        inspector_log = f.path
    else:
        match = re.match(r"baremetal-operator-ironic-(?P<id>[0-9]*)-(?:.*)", f.name)
        if match is None:
            print("wrong regex")
        else:
            ironic_id = match.group("id")
            ironic_logs[ironic_id] = f.path

print(inspector_log)
print(ironic_logs)

contents = {}

with open(inspector_log) as f:
    lines = f.readlines()

contents["inspector"] = lines

for idx, ironic_log in ironic_logs.items():
    with open(ironic_log) as f:
        contents[f"ironic-{idx}"] = f.readlines()

# regex = r'Node (?P<node_name>([0-9]|[a-z]|-)*) is locked by host (?P<host_name>(\d|\.)*), please'
# nodes = {}
# for line in lines:
#     match = re.search(regex, line)
#     if match is not None:
#         node_name = match.group("node_name")
#         host_name = match.group("host_name")
#         hosts = nodes.get(node_name, [])
#         if host_name not in hosts:
#             hosts.append(host_name)
#             nodes[node_name] = hosts

def get_container_logs(container):
    proc = subprocess.run(["sudo", "podman", "logs", container], capture_output=True)
    log = proc.stderr.decode()
    with open(os.path.join(separated_logs_dir, f"{container}-logs.txt"), "w") as f:
        f.write(log)
    return log

for container in ["fake-ipa", "sushy-tools"]:
    log = get_container_logs(container)
    contents[container] = log

with open(os.path.join(__dir__, 'nodes.json')) as f:
    nodes_info = json.load(f)

node_names = [node['name'] for node in nodes_info]

def get_node_conductor(name):
    out = subprocess.check_output(["baremetal", "node", "show", name, "-f", "json"])
    content = json.loads(out)
    uuid = content.get("uuid")
    conductor = content.get("conductor")
    print(name, uuid, conductor)
    return (name, uuid, conductor)

with Pool(100) as p:
    nodes = p.map(get_node_conductor, node_names)

for name, uuid, hosts in nodes:
    if hosts is None:
        continue
    node_logs_dir = os.path.join(separated_logs_dir, name)
    os.makedirs(node_logs_dir, exist_ok=True)
    for f, lines in contents.items():
        filtered = [line for line in lines if uuid in line]
        if len(filtered) == 0:
            continue
        with open(os.path.join(node_logs_dir, f"{f}.txt"), "w") as f:
            f.write("\n".join(filtered))
