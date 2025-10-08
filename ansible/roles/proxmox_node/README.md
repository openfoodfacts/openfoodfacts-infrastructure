# Proxmox Node role

This role installs and configures a Proxmox node,
that is a server which is part of a Proxmox cluster.

It take cares of:
* creating partitions (only use if needed)
* installing ZFS (using aisbergg.zfs)
* installing and configuring Proxmox (using lae.proxmox role)
* configure network interfaces

## Creating partitions

You can declare partitions to ensure they are as expected.

By default this is just a check.

If you need to remove/create them then you will need to add
`-e proxmox_node__mkparts=true` to you ansible-playbook command line.

You might also bring modifications manually on the host,
and check back by running ansible again.

This prevent altering partitions by error !

## Creating a cluster

You will have to:
* create a group in inventory using the cluster name
  (note: it must not contains "_", but can contain"-")
* add group_vars for the cluster and define:
  * `proxmox_node__pve_cluster_enabled: true`
  * and set `proxmox_node__pve_cluster_name` to the group name
* in host vars for the host:
  * set `proxmox_node__pve_cluster_addr0` to the private network address of the host
  * eventually set `proxmox_node__pve_cluster_addr1` to the public network address of the host

Then you will have to run the playbook for all the hosts in the group, at the same time.
The recipe will chose on of the host as the initial node for the cluster.