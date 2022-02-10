[main page](README.md)|[experiments](experiments/AIR-140_.md)

---

# Autoconfiguration of Load Balancers

**Key objectives**: Creating LB and masters setup automatically before running kubeadm init/join.

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

        II. After each master boots and runs init or join
       III. After each master is down

Notes:

There are some corner cases that are ignored for now and should be studied further at implementation phase. For example:

- Case (II) above does not work if the LB boots after the masters

## Load Balancer options

### External Load Balancers
Based on the parameters we defined earlier, taking nginx as an example, we can state the following.

Responsibility and Timing:

For all time instances give above, Nginx is a passive entity and cannot configure itself.

- After each master boots and runs init or join:
Nginx is a passive entity and cannot configure the rule itself.

- After each master is down:
This resembles health check and nginx can remove the rule after some time

**Therefore**, masters should be responsible for adding a rule on the LB during their boot. However, there is no clear solution for removing a rule as a master's graceful shutdown is not guaranteed.

### Keepalived

In this case, we have three masters, each with its own IP and one VIP shared among them. At any given moment in time, the VIP is associated with one of the masters.

Responsibility and Timing:

It is not possible to assign responsibility to the "LB" as there is just a VIP that floats among the masters, but for the timing, we can consider the following. 

- After each master boots and runs init or join:
All masters know the VIP before boot via the keepalived configuration file and no need to configure anything.

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

- After each master boots and runs init or join:
Masters should NOT advertize routes before they run init or join.

- After each master is down: 
LB should be able to detect a master's absence and remove the corresponding rule.

**Therefore**, both masters and LB are responsible for creating the maintaining the setup.

### Open questions and future works

Choosing the best LBs for specific uses is open question and requires further discussion in the community. We give priority for options that are (being) used in production.

Any solution we choose should be easily implemented as cloud-init so that machines are boot in ANY order and the LB is setup successfully.

## Open Questions

1. Who creates/removes the load balancer ?
With cluster-api, we can create the masters, but there is no way to crate the load balancer.
- Should one of the masters spawn a load balancer ?
- Should an external controller, script or the ephemeral node create the load balancer ?

2. who is responsible for creating the rules after each master run init or join ?
- Each master creates its own rule ?
- Should an external controller, script or the ephemeral node create a rule for itself ?


2. who is responsible for deleting the rules after each master leaves or dies ungracefully ?
- Each master deletes its own rule ? not possible if the master dies ungracefully.
- Should an external controller, script or the ephemeral node delete the rules ?
- The load balancer itself after timeout ?
