# Introduction
The purpose of this document is for studying the limitations of kubeadm in accomplishing the tasks done by airship components. Each task is mapped to a jira issue and focuses on some specific topic as outlined during a face to face meeting. The original meeting points can found in Gaps section here: [Airship_F2f_Notes](https://etherpad.openstack.org/p/Airship_F2f_Notes)

# Tasks
- [x] [Rotate certificates](AIR-138_kubeadm-rotating-ca.md)
- [x] [Study Load balancer options](AIR-139_140_loadbalancers.md)
- [x] [Configure container run for a cluster](AIR-141_runtimeclass.md)
- [x] [Pass encryption key and more certs to kubeadm](AIR-142_enrypt-data-at-rest_and_provide-more-certs.md)

- [x] [Configure registry and tag for pause container images](AIR-148_pause-containers-selection.md)
- [x] [Configure registry and tag for k8s control plane images](AIR-149_k8s-image-and-tags-selection.md)
- [x] [Dictate which interfaces control plane components can use](AIR-146_non-default-ip-for-master.md)

# Ongoing tasks
- [ ] [Use sha256 values for docker operations](https://airship.atlassian.net/browse/AIR-147)
