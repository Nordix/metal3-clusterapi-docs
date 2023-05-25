import os
import shutil
import re

__dir__ = os.path.abspath(os.path.dirname(__file__))
logs_dir = os.path.join(__dir__, "logs")
separated_logs_dir = os.path.join(__dir__, "separated_logs")

shutil.rmtree(separated_logs_dir)
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

regex = r'Node (?P<node_name>([0-9]|[a-z]|-)*) is locked by host (?P<host_name>(\d|\.)*), please'
nodes = {}
for line in lines:
    match = re.search(regex, line)
    if match is not None:
        node_name = match.group("node_name")
        host_name = match.group("host_name")
        hosts = nodes.get(node_name, [])
        if host_name not in hosts:
            hosts.append(host_name)
            nodes[node_name] = hosts
for node, hosts in nodes.items():
    print(f"{node}: {', '.join(hosts)}")
    node_logs_dir = os.path.join(separated_logs_dir, node)
    os.makedirs(node_logs_dir, exist_ok=True)
    for f, lines in contents.items():
        filtered = [line for line in lines if node in line]
        if len(filtered) == 0:
            continue
        with open(os.path.join(node_logs_dir, f"{f}.txt"), "w") as f:
            f.write("\n".join(filtered))
