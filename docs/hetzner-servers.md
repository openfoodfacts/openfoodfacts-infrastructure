# Hetzner Servers

We have some servers at Hetzner.

## Console

You can access the console at https://robot.hetzner.com.

## vSwitch

Because some of our servers have only one NIC (Network Interface Card),
we need to use a vSwitch to connect our servers in a private network
(which is handy for a proxmox cluster).

[Official documentation for vswitch](https://docs.hetzner.com/robot/dedicated-server/network/vswitch/)

### Troubleshouting vswitch

If private network as problems,
in particular if `ip neigh` shows you FAILED resolutions of ip,
see [hetzner vswitch section to troubleshout it](https://docs.hetzner.com/robot/dedicated-server/network/vswitch/#troubleshooting-vswitch-connection-issues)
and try to reset, or remove servers and add them again
(see [this report](./reports/2025-12-16-hetzner-vswitch-not-working.md))