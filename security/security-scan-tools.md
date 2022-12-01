# Security vulnerabilily tools Kube-hunter and Kube-bench

There are some vulnerability detection tools available, such as **kube-hunter** and **kube-bench** for kubernetes cluster. User can check and scan cluster both from inside or outside of the kubernetes cluster. The following information can be used for future use of these vulnerability tools in **metal3-dev-env**. Here is the step by step instructions for using **kube-hunter** and **kube-bench** as a vulnerability tool.

## **Kube-hunter**

* Installing kube-hunter

```bash
  which pip
  pip --version
  kubelet --version
  pip install --user kube-hunter
  which kube-hunter
  kube-hunter --help
  kube hunter

```

* **kube-hunter** command will list options for scanning the cluster, choose 1 for remote scanning and provide the internal IP for the node. It will print the following as a scan result for kind cluster.

```text

Vulnerabilities
For further information about a vulnerability, search its ID in:
https://avd.aquasec.com/

+--------+-----------------+----------------------+----------------------+----------------------+----------+
| ID     | LOCATION        | MITRE CATEGORY       | VULNERABILITY        | DESCRIPTION          | EVIDENCE |
+--------+-----------------+----------------------+----------------------+----------------------+----------+
| KHV002 | 172.18.0.2:6443 | Initial Access //    | K8s Version          | The kubernetes       | v1.23.4  |
|        |                 | Exposed sensitive    | Disclosure           | version could be     |          |
|        |                 | interfaces           |                      | obtained from the    |          |
|        |                 |                      |                      | /version endpoint    |          |
+--------+-----------------+----------------------+----------------------+----------------------+----------+

```

* User can check the cluster from ephemeral cluster and give the internal ip for master and worker. For control plane node the output can be shown as:

```text

Vulnerabilities
For further information about a vulnerability, search its ID in:
https://avd.aquasec.com/

+--------+----------------------+----------------------+----------------------+----------------------+----------+
| ID     | LOCATION             | MITRE CATEGORY       | VULNERABILITY        | DESCRIPTION          | EVIDENCE |
+--------+----------------------+----------------------+----------------------+----------------------+----------+
| KHV002 | 192.168.111.100:6443 | Initial Access //    | K8s Version          | The kubernetes       | v1.23.5  |
|        |                      | Exposed sensitive    | Disclosure           | version could be     |          |
|        |                      | interfaces           |                      | obtained from the    |          |
|        |                      |                      |                      | /version endpoint    |          |
+--------+----------------------+----------------------+----------------------+----------------------+----------+

```

* User can scan the for vulnerabilities from the control plane or worker node. Follow the same installation of kube-hunter and scan the cluster.
* The ID **KHV00**2 indicates the information ID regarding the vulnerability. User can check the details and get remediation suggestion from this [link](https://avd.aquasec.com/).
* We approached to test the scanning from inside the cluster whrere **kube-hunter** will run inside the cluster as a pod. But facing issues regarding cluster access. This issue was happening with many other users of this tool but no visible solution was given by the community.
* Running the **kube-hunter** tests inside the cluster could be substituted by running **kube-bench** inside the cluster as explained in the next chapter.
* The following information was printed when tried to run as a pod inside the cluster.

```text

kubectl logs pod/kube-hunter-nhsdw

Vulnerabilities
For further information about a vulnerability, search its ID in:
https://avd.aquasec.com/
+--------+----------------------+----------------------+----------------------+----------------------+----------------------+
| ID     | LOCATION             | MITRE CATEGORY       | VULNERABILITY        | DESCRIPTION          | EVIDENCE             |
+--------+----------------------+----------------------+----------------------+----------------------+----------------------+
| KHV053 | Local to Pod (kube-  | Discovery //         | AWS Metadata         | Access to the AWS    | cidr: <html>         |
|        | hunter-nhsdw)        | Instance Metadata    | Exposure             | Metadata API exposes |  <head>              |
|        |                      | API                  |                      | information about    |   <title>404 Not     |
|        |                      |                      |                      | the machines         | Found</title>        |
|        |                      |                      |                      | associated with the  |  <                   |
|        |                      |                      |                      | cluster              |                      |
+--------+----------------------+----------------------+----------------------+----------------------+----------------------+
| None   | Local to Pod (kube-  | Credential Access // | Access to pod\'s      | Accessing the pod's  | '/var/run/secrets/k |
|        | hunter-nhsdw)        | Access container     | secrets              | secrets within a     | ubernetes.io/service |
|        |                      | service account      |                      | compromised pod      | account/ca.crt', '/v |
|        |                      |                      |                      | might disclose       | ar/run/secrets/kuber |
|        |                      |                      |                      | valuable data to a   | netes.io/serviceacco |
|        |                      |                      |                      | potential attacker   | ...                  |
+--------+----------------------+----------------------+----------------------+----------------------+----------------------+
| KHV050 | Local to Pod (kube-  | Credential Access // | Read access to pod\'s | Accessing the pod    | eyJhbGciOiJSUzI1NiIs |
|        | hunter-nhsdw)        | Access container     | service account      | service account      | ImtpZCI6ImVUWGJWOEp5 |
|        |                      | service account      | token                | token gives an       | ZFZZN2dLTjItUUlzTXdW |
|        |                      |                      |                      | attacker the option  | eDItYVd6YVM1a0tHR3dL |
|        |                      |                      |                      | to use the server    | a3BGVFkifQ.eyJhdWQiO |
|        |                      |                      |                      | API                  | ...                  |
+--------+----------------------+----------------------+----------------------+----------------------+----------------------+
Kube Hunter couldn\'t find any clusters
```

## **Kube-bench**

* Kube-bench will be used here from inside the kubernetes cluster and it will run as a pod.
* Apply the following [job.yaml](https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml) file and when the pod is up running and scan job is completed, check the logs of the the pod. It will show the scanning result with remediation suggestion. The following output will show the basic result of **kube-bench** scanning. Here is an example output in the cluster with trimmed text.

```text

kubectl logs pod/kube-bench-tqmzr
[INFO] 1 Control Plane Security Configuration
[INFO] 1.1 Control Plane Node Configuration Files
[PASS] 1.1.1 Ensure that the API server pod specification file permissions are set to 644 or more restrictive (Automated)
[PASS] 1.1.2 Ensure that the API server pod specification file ownership is set to root:root (Automated)
[PASS] 1.1.3 Ensure that the controller manager pod specification file permissions are set to 644 or more restrictive (Automated)
[PASS] 1.1.4 Ensure that the controller manager pod specification file ownership is set to root:root (Automated)
[PASS] 1.1.5 Ensure that the scheduler pod specification file permissions are set to 644 or more restrictive (Automated)
[PASS] 1.1.6 Ensure that the scheduler pod specification file ownership is set to root:root (Automated)
[PASS] 1.1.7 Ensure that the etcd pod specification file permissions are set to 644 or more restrictive (Automated)
[PASS] 1.1.8 Ensure that the etcd pod specification file ownership is set to root:root (Automated)
[WARN] 1.1.9 Ensure that the Container Network Interface file permissions are set to 644 or more restrictive (Manual)
[WARN] 1.1.10 Ensure that the Container Network Interface file ownership is set to root:root (Manual)
[PASS] 1.1.11 Ensure that the etcd data directory permissions are set to 700 or more restrictive (Automated)
[FAIL] 1.1.12 Ensure that the etcd data directory ownership is set to etcd:etcd (Automated)
[PASS] 1.1.13 Ensure that the admin.conf file permissions are set to 600 or more restrictive (Automated)
[PASS] 1.1.14 Ensure that the admin.conf file ownership is set to root:root (Automated)
[PASS] 1.1.15 Ensure that the scheduler.conf file permissions are set to 644 or more restrictive (Automated)

== Remediations master ==
1.1.9 Run the below command (based on the file location on your system) on the control plane node.
For example, chmod 644 <path/to/cni/files>

1.1.10 Run the below command (based on the file location on your system) on the control plane node.
For example,
chown root:root <path/to/cni/files>


== Summary master ==
42 checks PASS
9 checks FAIL
11 checks WARN
0 checks INFO

```

## **Links**

* [*Kube-hunter docs*](https://aquasecurity.github.io/kube-hunter/)
* [*kube-bench docs*](https://github.com/aquasecurity/kube-bench/blob/main/docs/running.md)
* [*job.yaml file for kube-bench*](https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml)
