# 2025-12-16 Hetzner vswitch not working

While installing the VM for setting up query postgres,
tempting to "scp" a file between the cluster nodes,
it was not working.

## Diagnosis

Trying to connect to ssh failed

```bash
# ssh -vvv 10.12.0.2
debug1: OpenSSH_10.0p2 Debian-7, OpenSSL 3.5.4 30 Sep 2025
debug3: Running on Linux 6.14.11-4-pve #1 SMP PREEMPT_DYNAMIC PMX 6.14.11-4 (2025-10-10T08:04Z) x86_64
debug3: Started with: ssh -vvv 10.12.0.2
...
debug1: Connecting to 10.12.0.2 [10.12.0.2] port 22.
debug3: set_sock_tos: set socket 3 IP_TOS 0x10
```
it was stalled with this last line.

I had the same problem with `10.12.0.1` and reciprocally,
ping did not work either between hosts.
I could connect from scaleway-02 to scaleway-01 though…

After some times of trying various thing,
and thinking that maybe my MASQUERADE rule in iptables was not correct [^iptable-masquerade].

But after sometimes I looked at arp cache.
On scaleway-02 it gave me something like:
```bash
arp
    Address                  HWtype  HWaddress           Flags Mask            Iface
    static.65.90.99.88.clie  ether   40:71:83:a5:eb:97   C                     vmbr0
    hetzner-01.infra.openfo  ether   a8:a1:59:82:3b:4a   C                     vmbr1
    hetzner-03.infra.openfo          (incomplete)                              vmbr1
```
Using `ip neigh` is maybe a better command though.
It gave me
```bash
ip neigh
    88.99.90.65 dev vmbr0 lladdr 40:71:83:a5:eb:97 REACHABLE 
    10.12.0.1 dev vmbr1 lladdr a8:a1:59:82:3b:4a STALE 
    10.12.0.3 dev vmbr1 FAILED 
```

I tried `ip -s -s neigh flush all` to reset arp cache,
but it did not help.

[^iptable-masquerade]: indeed we could enhance it, changing from:
  `iptables -t nat -I POSTROUTING -m set --match-set PrivateNet4 src -j MASQUERADE`
  to
  `iptables -t nat -I POSTROUTING -m set --match-set PrivateNet4 src -m set ! --match-set PrivateNet4 dst -j MASQUERADE`
  and adequately for ipv6,
  that is, avoid to masquerade connections happening within the private network.

## Resolution

I decided to re-read the vswitch documentation to see if I was doing something wrong
(after re-reading my configurations various time).

I found [a section to troubleshout it](https://docs.hetzner.com/robot/dedicated-server/network/vswitch/#troubleshooting-vswitch-connection-issues)

I tried to use the "refresh" button, but it did nothing,
so as proposed by their docs, I removed all servers, and add them again.
After that it started to work !

This is really sad !