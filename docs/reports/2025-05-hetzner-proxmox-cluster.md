# 2025-05 hetzner proxmox cluster

We have setup proxmox servers (see [2025-02-18 more hetzner server install](./2025-02-18-more-hetzner-server-install.md), and [2024-11-14 hetzner server install](./2024-11-14-hetzner-server-install.md)) and configure them with ansible,
but they are yet to be set as a single cluster.

## Setting up the vSwitch

We need a vSwitch to connect our servers in a private network (which is handy for a proxmox cluster).

In robot console of hetzner, I created a vSwitch with ID 4000.
I added hetzner-01,02 and 03 servers.

I then follow [documentation](https://docs.hetzner.com/robot/dedicated-server/network/vswitch/#server-configuration-linux) to add interfaces to our servers.

FIXME: explain ansible configuration