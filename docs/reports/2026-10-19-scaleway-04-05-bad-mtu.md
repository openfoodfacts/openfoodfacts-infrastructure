# 2026-10-19 scaleway-04/05 bad MTU

## Symptoms

Thomas reported problems with ipv6 configuration
while [installing scaleway-04 and scaleway-05](./2026-10-10-migrating-off1-off2-to-scaleway-04-05.md)

On my side, I was unable to connect using scaleway-04/05 internal address
from one to another (while it worked for other servers…)

## Diagnosis

After several investigation, and notably using `ssh -vvv`,
I stumbled upon this [stackexchange thread and response](https://unix.stackexchange.com/a/786463/437686) about the same error I had (ssh stuck on `debug1: expecting SSH2_MSG_KEX_ECDH_REPLY`),
where the author points to a possible MTU problem.

Indeed I tried a `ping -M do -s 8972 10.13.0.4` from scaleway-05 and it did not work,
while `ping -M do -s 1400 10.13.0.4` was working.

Analyzing the `/etc/network/interfaces` configuration
I realized that while we set a `mtu 9000` on `vmbr1`
the mtu was not set on the corresponding interface (`eno2` on scaleway-05).

Note: `mtu 9000` correspond to the so called [Jumbo Frame](https://en.wikipedia.org/wiki/Jumbo_frame)
option of ethernet.
It is interesting to set it on local network where we control the interfaces.
On interfaces communicating with internet, a conservative `mtu 1400` is better.

I can test by using: `sudo ip link set dev eno2 mtu 9000`

If I do the same on `scaleway-04`,
I'm able to ssh from one to another without being blocked.

## Fix

I decided to fix it on every servers.

For scaleway-04 and scaleway-05 I edited the `/etc/network/interfaces`
to set `mtu 9000` on physical links supporting the private bridge (`vmbr1`).
I then use `systemctl restart networking.service` to verify it was working correctly.

On the other server, to avoid disruption I just modified the `/etc/network/interfaces` files
to add `mtu 9000` to the relevant interfaces
(all the physical link and bridge the private bridge rely upon)
and issued `sudo ip link set dev <link-name> mtu 9000`
corresponding to my changes.

## IPv6

After this change being made,
I did try to add the ipv6 interfaces to scaleway-04 and scaleway-05
and noticed that it was now working correctly.