[main page](README.md)|[experiments](experiments/AIR-140_.md)

---

# Autoconfiguration of Load Balancers

Jira Issues: 
- [metallb](https://airship.atlassian.net/browse/AIR-5)
- [keepalived](https://airship.atlassian.net/browse/AIR-140)

## Introduction

**The problem:**

Given a set of control plane nodes (masters) and a load balancer, we would like to configure the load balancer automatically. In this context, configuration means adding a rule on the load balancer for a specific master.

Topology:

```
          |  M1
          | 
LB -----> |  M2
          |
          |  M3
```

**The task:**

Define parameters for comparing different load balancers and choose suitable ones for different use cases. Any human intervention should END before the machines boot. i.e. We have an LB, masters and nothing else. With the information given in cloud-init, the machines should be able to do the setup.

**Parameters**

 **responsibility:** Who is responsible configuring the load balancer

        A. The master machine
        B. The load balancer itself

**Timiming:** When is an entry for a master machine in the LB created/deleted:

         I. Before booting the machines
        II. After each master boots
       III. After each master is down

Notes:

There are some corner cases that are ignored for now and should be studied further at implementation phase. For example:

- Case (I) above does not work in a dhcp environment
- Case (II) above does not work if the LB boots after the masters

## Load Balancer options

### External Load Balancers
Based on the parameters we defined earlier, taking nginx as an example, we can state the following.

Responsibility and Timing:

For all time instances give above, Nginx is a passive entity and cannot configure itself.

- Before booting the machines:
This is possible if the masters have static addresses.

- After each master boots:
This is not possible as nginx is a passive entity.

- After each master is down:
This resembles health check and is not applicable as we could have a different meaning for what unhealthy masters is. But, this could be discussed further during implementation phase.

**Therefore**, masters should be responsible for adding a rule on the LB during their boot. However, there is no clear solution for removing a rule as a master's graceful shutdown is not guaranteed.

### Keepalived

In this case, we have three masters, each with its own IP and one VIP shared among them. At any given moment in time, the VIP is associated with one of the masters.

Responsibility and Timing:

It is not possible to assign responsibility to the "LB" as there is just a VIP that floats among the masters, but for the timing, we can consider the following. 

- Before booting the machines:
All masters know the VIP before boot via the keepalived configuration file.

- After each master boots:
The same reasoning as above applies.

- After each master is down:
One of the remaining masters takes the VIP.

**Therefore**, masters are responsible for configuring the "LB"

### BGP

Before going further we need to make the following assumptions.

- There is NO kubernetes cluster.
- BGP router runs in the LB and speakers live in each master
- We refer to the router as LB since it is the only process in the LB.
- Masters are created with the knowledge of how to reach the LB 

Responsibility and Timing:
The LB learns about routes on the masters from each master. Configuring which networks the masters should advertise is a topic for further study.

- Before booting the machines:
This is not possible as the setup requires active BGP components

- After each master boots: 
The same reasoning as above applies.

- After each master is down: 
This is much like asking, if a master is down, when does the LB become aware of it and delete the corresponding rule ? This requires configuring the LB to health check frequently enough to detect such failures. This requires further study.

**Therefore**, both masters and LB are responsible for creating the maintaining the setup.

### The best LB and the future works

Choosing the best LBs for specific uses is open question and requires further discussion in the community. We give priority for options that are (being) used in production.

Any solution we choose should be easily implemented as cloud-init so that machines are boot in ANY order and the LB is setup successfully.