# IRONIC RESOURCE LIMITATION

This report contains the results of experiments to measure minimal CPU and memory consumption of ironic pod. The experiments are conducted with different number of BMHs, and these numbers allow engineers to estimate the minimal amount of resources Ironic pod required given any specific number of BMHs, ranging from 4 to 40.

## Experiment environment

Operating system: `Ubuntu 20.04.3 LTS`

Management cluster: Minikube

Metric collector: Prometheus in cluster

Data visualizer: Grafana in cluster

Merics:

 For memory usage: `container_memory_working_set_bytes / 1000000`

The reason is that Kubernetes uses this metric to determine whether it should kill the container because of OOM: <https://docs.newrelic.com/whats-new/2021/03/kubernetes-whats-new/>. The division to 1000000 is for conversion from byte to Megabyte.

 For CPU usage: `rate(container_cpu_usage_seconds_total[10m]) * 1000`

`container_cpu_usage_seconds_total` measures the number of seconds one container uses CPU. In detail, if one container uses 1 second CPU in 1 second, that container uses 100% of one CPU core (1000 milicore) in that moment. Similarly, if it uses 0.5 second, it uses 500 milicore, and 2 seconds mean 2000 milicore. However, this metric is aggregating over time, so using it alone is not enough.

`rate()[10m]` calculates the per-second average rate of increase of the time series of 10 minutes in the range vector. <https://prometheus.io/docs/prometheus/latest/querying/functions/#rate>. In short, combine with the above function, `rate()` measures the number of CPU seconds at any point in the timeline. The 10 minutes time range decides how sharp the plot is. The larger time range, the flatter the plot. 10-minute-duration is chosen to make the plot not too much frustrated, but also indicating some ideas about how much CPU a container can consume in a specific moment. To convert to milicore, a multiply to 1000 is needed.

Experiment: This experiment is based on metal3 integration test. Prometheus is installed into Minikube cluster after it starts. It monitors all activities of Ironic pod in a integration test, including instropecting, provisioning,...

## 4 BMHs

```text
+----------------------------+------------+---------------+
|         Container          | Memory(MB) | CPU(milicore) |
+----------------------------+------------+---------------+
| ironic-api                 |        466 |          43.7 |
| ironic-conductor           |        226 |          24.1 |
| ironic-inspector           |        100 |          12.8 |
| mariadb                    |       84.5 |            12 |
| ironic-dnsmasq             |       3.08 |          1.26 |
| ironic-log-watch           |        2.6 |          1.64 |
| ironic-endpoint-keepalived |       2.27 |         0.145 |
| Sum                        |        870 |          90.5 |
+----------------------------+------------+---------------+
```

Memory usage by each container
![memory_4BMHs][5]
Sum memory usage
![sum_memory_4BMHs][6]
CPU usage by each container
![cpu_4BMHs][7]
Sum CPU usage
![sum_cpu_4BMHs][8]

## 10 BMHs

```text
+----------------------------+------------+---------------+
|         Container          | Memory(MB) | CPU(milicore) |
+----------------------------+------------+---------------+
| ironic-api                 |        490 |          87.9 |
| ironic-conductor           |        236 |          44.4 |
| ironic-inspector           |        105 |          16.7 |
| mariadb                    |       85.7 |          65.7 |
| ironic-dnsmasq             |       4.98 |          1.26 |
| ironic-log-watch           |        3.1 |          2.13 |
| ironic-endpoint-keepalived |       2.27 |         0.183 |
| Sum                        |        910 |           211 |
+----------------------------+------------+---------------+
```

Memory usage by each container
![memory_10BMHs][2]
Sum memory usage
![sum_memory_10BMHs][1]
CPU usage by each container
![cpu_10BMHs][3]
Sum CPU usage
![sum_cpu_10BMHs][4]

## 15 BMHs

```text
+----------------------------+------------+---------------+
|         Container          | Memory(MB) | CPU(milicore) |
+----------------------------+------------+---------------+
| ironic-api                 |        482 |           167 |
| ironic-conductor           |        243 |          59.7 |
| ironic-inspector           |        100 |          19.1 |
| mariadb                    |       88.5 |          39.6 |
| ironic-dnsmasq             |       3.26 |          1.32 |
| ironic-log-watch           |       2.56 |           2.8 |
| ironic-endpoint-keepalived |       2.44 |         0.188 |
| Sum                        |        909 |           284 |
+----------------------------+------------+---------------+
```

Memory usage by each container
![memory_15BMHs][9]
Sum memory usage
![sum_memory_15BMHs][10]
CPU usage by each container
![cpu_15BMHs][11]
Sum CPU usage
![sum_cpu_15BMHs][12]

## 20 BMHs

```text
+----------------------------+------------+---------------+
|         Container          | Memory(MB) | CPU(milicore) |
+----------------------------+------------+---------------+
| ironic-api                 |        503 |           234 |
| ironic-conductor           |        224 |            85 |
| ironic-inspector           |        101 |          24.7 |
| mariadb                    |         89 |          66.2 |
| ironic-dnsmasq             |       3.58 |          1.83 |
| ironic-log-watch           |        2.7 |             4 |
| ironic-endpoint-keepalived |       2.28 |         0.226 |
| Sum                        |        902 |           408 |
+----------------------------+------------+---------------+
```

Memory usage by each container
![memory_20BMHs][13]
Sum memory usage
![sum_memory_20BMHs][14]
CPU usage by each container
![cpu_20BMHs][15]
Sum CPU usage
![sum_cpu_20BMHs][16]

## 30 BMHs

```text
+----------------------------+------------+---------------+
|         Container          | Memory(MB) | CPU(milicore) |
+----------------------------+------------+---------------+
| ironic-api                 |        534 |           273 |
| ironic-conductor           |        185 |           125 |
| ironic-inspector           |        102 |          42.8 |
| mariadb                    |       92.7 |           103 |
| ironic-dnsmasq             |       3.74 |          3.63 |
| ironic-log-watch           |       3.81 |          4.75 |
| ironic-endpoint-keepalived |       2.58 |         0.365 |
| Sum                        |        901 |           439 |
+----------------------------+------------+---------------+
```

Memory usage by each container
![memory_30BMHs][17]
Sum memory usage
![sum_memory_30BMHs][18]
CPU usage by each container
![cpu_30BMHs][19]
Sum CPU usage
![sum_cpu_30BMHs][20]

## 40 BMHs

```text
+----------------------------+------------+---------------+
|         Container          | Memory(MB) | CPU(milicore) |
+----------------------------+------------+---------------+
| ironic-api                 |        527 |           380 |
| ironic-conductor           |        163 |           123 |
| ironic-inspector           |        101 |          52.1 |
| mariadb                    |       92.6 |          46.7 |
| ironic-dnsmasq             |        3.6 |          2.74 |
| ironic-log-watch           |       3.35 |          2.96 |
| ironic-endpoint-keepalived |        2.4 |         0.198 |
| Sum                        |        860 |           597 |
+----------------------------+------------+---------------+
```

Memory usage by each container
![memory_40BMHs][21]
Sum memory usage
![sum_memory_40BMHs][22]
CPU usage by each container
![cpu_40BMHs][23]
Sum CPU usage
![sum_cpu_40BMHs][24]

[1]: Images/sum_memory_10.png
[2]: Images/memory_10.png
[3]: Images/cpu_10.png
[4]: Images/sum_cpu_10.png
[5]: Images/memory_4.png
[6]: Images/sum_memory_4.png
[7]: Images/cpu_4.png
[8]: Images/sum_cpu_4.png
[9]: Images/memory_15.png
[10]: Images/sum_memory_15.png
[11]: Images/cpu_15.png
[12]: Images/sum_cpu_15.png
[13]: Images/memory_20.png
[14]: Images/sum_memory_20.png
[15]: Images/cpu_20.png
[16]: Images/sum_cpu_20.png
[17]: Images/memory_30.png
[18]: Images/sum_memory_30.png
[19]: Images/cpu_30.png
[20]: Images/sum_cpu_30.png
[21]: Images/memory_40.png
[22]: Images/sum_memory_40.png
[23]: Images/cpu_40.png
[24]: Images/sum_cpu_40.png
