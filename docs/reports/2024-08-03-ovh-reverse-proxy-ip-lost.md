# 2024-08-03 OVH Reverse proxy IP lost

## Problem

Friday 03-08-2024, around 16:40 all the service on OVH cease to be accessible over http.

Unfortunately a lot of the team was on vacation.

## Investigation

We did some reboot of the reverse proxy container without success.

After some investigation, it appears that it could not communicate with the rest of internet:
outgoing and ingoing requests where lost.

Looking at `ip neigh` I saw that the gateway was not reachable.

```bash
10.1.0.100 dev eth0 lladdr d6:7b:64:f7:28:08 STALE
10.0.0.1 dev eth0 lladdr a0:42:3f:46:e7:6d STALE
193.70.55.1 dev eth1  FAILED
fe80::7ead:4fff:fea0:d657 dev eth1 lladdr 7c:ad:4f:a0:d6:57 router STALE
fe80::7ead:4fff:fea0:b087 dev eth1 lladdr 7c:ad:4f:a0:b0:87 router STALE
```

Looking at the OVH incidents panel,
I saw that there was an [incident in progress on bare metal servers](https://bare-metal-servers.status-ovhcloud.com/) at RBX8 (same location as our server),
but it was not on the rack containing OVH1.



## Resolution

### Asking support

Having no explanation for this sudden change in gateway reachability,
I opened a ticket to OVH support at 20:30, concerning network ip failover.
And hoped that they will answer fast.

I was on vacation and did this in the train.
I did not have the time, nor the mean to find a temporary fix.

As I arrived destination (around 22), I had no answer.
I then was AFK for whole week-end !

On monday I checked and see that RBX8 incident was resolved,
while reverse proxy was still failing and our ticket didn't get any answer.

### Adding a new IP

As suggested by Vince and Christian in between, we decided to try to change our IP address by requiring on additional IP address from OVH.

#### Putting our secondary OVH account as technical contact

The account containing the servers (OVH Mecenat) can't be used to buy anything.
We have a second OVH account, where we manage domain name,
but you can only add an additional IP address to the server you possess.
The trick is that you can do this if you are the technical contact of the server.

So in the OVH admin interface, We did go to bare metal servers, choosed OVH1, and at the bottom,
I asked to modify contacts. we were able to nominate the new technical contact.

This sends two mails for verification:
* one to the new technical contact account
* one to the owner of the server

After validation, some minutes later, the contact was changed.

In the contact modification form, there is a tab were you can see tasks in progress and their status.


#### Purchasing an additional IP

Now using the new technical contact account, we went to the IP section, in bare metal cloud 
and we were able to purchased an additional IP for ovh1 server.

I then try to configure it on my proxmox container (see below), but it was not working.

Indeed, OVH associate IP address with a MAC, and by default this is the MAC of the server.
So I had to add a virtual MAC (it's possible in OVH interface showing additional IP address).
I put the MAC address of the container (visible in proxmox admin interface, in the network tab for the container),
saying it was a VM Ware virtual MAC.

### Changing the IP of the container

#### Changing the IP

Using proxmox admin, I changed the IP of the container.
I had no way of knowing the gateway, so I had to guess it (OVH considers you have to use DHCP, but we hardcode IP, and proxmox does not let you use DHCP only for part of the configuration[^proxmox_dhcp_gateway] ).
Trying 1 and 254, I was able to get it correctly (it was the same IP as the one we have, changing last part to 254).
`ip neigh` helped me to check reachability.

As said above, it did not work at first try because we had to associate the virtual MAC with the IP address in OVH interface 
(that's good news OVH does this kind of checks)

[^proxmox_dhcp_gateway]: in practice this could be done by manually changing the network configuration in the container,
  but I prefer to keep things simple and use proxmox admin (we are different admins).

#### Updating DNS

We updated the DNS record for openfoodfacts.org and openfoodfacts.net to point to the new IP address.
In practice we only changed proxy1.openfoodfacts.org and openfoodfacts.net, because the other are CNAME
(and those which weren't, now are).

## Conclusion

We still don't know why our gateway became sudenly unreachable…

We had two days of downtime, because we had few resources available, and we did not identified any quick fix (even temporary).
Most of the services keeps running and could do their job, but were unreachable (API, blog, etc.).

We now have an IP address that is under the control of our team.

Some possible actions in the future:
* We could use this more:
  * for example to setup a second reverse proxy on ovh2, and have a failover.
  * We could also use additional IP for the [mail gateway](../mail.md).
* We should investigate using IPv6 on those containers