# 2023-05-23 off2 - container 110 unreachable from 101

### Problem

Something strange on off2, I was trying to debug a bad gateway on opff install. The problem was supposedly between the nginx proxy (on CT 101) and the opff nginx (on CT 110). So I wanted to debug.
I tried to curl from 101 to 110
```bash
curl 10.1.0.110:80 -H "HOST: fr.openpetfoodfacts.org" -H "X-Forwarded-Proto: https" 
curl: (7) Failed to connect to 10.1.0.110 port 80: Connection refused
```
So I tried same command directly on CT 110 to verify nginx was working fine and it did work.
I then tried to ping 110 from 101, it's all fine:
```bash
# ping 10.1.0.110
PING 10.1.0.110 (10.1.0.110) 56(84) bytes of data.
64 bytes from 10.1.0.110: icmp_seq=1 ttl=64 time=0.161 ms
64 bytes from 10.1.0.110: icmp_seq=2 ttl=64 time=0.195 ms
64 bytes from 10.1.0.110: icmp_seq=3 ttl=64 time=0.187 ms
^C
--- 10.1.0.110 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2027ms
```
I tried to ping 101 for 110 and it took some time:
```bash
# ping 10.1.0.101
PING 10.1.0.101 (10.1.0.101) 56(84) bytes of data.
64 bytes from 10.1.0.101: icmp_seq=7 ttl=64 time=0.040 ms
64 bytes from 10.1.0.101: icmp_seq=8 ttl=64 time=0.055 ms
64 bytes from 10.1.0.101: icmp_seq=9 ttl=64 time=0.027 ms
64 bytes from 10.1.0.101: icmp_seq=10 ttl=64 time=0.055 ms
^C
--- 10.1.0.101 ping statistics ---
10 packets transmitted, 4 received, 60% packet loss, time 9203ms
rtt min/avg/max/mdev = 0.027/0.044/0.055/0.011 ms
```
as you can see the first 6 pings were lost…

After that I tried again the curl command from 101 and it worked !

## Possible causes

My analysis is that we may have some ARP tables / cache problems on CT 110 ? Is this something that reminds you something ?

Could be https://forum.proxmox.com/threads/debugging-sporadic-networking-problems-on-lxc.125259/ maybe ? Or https://forum.proxmox.com/threads/invalid-arp-responses-cause-network-problems.118128/ ?

a proposed fix is
net.ipv4.conf.all.arp_ignore=2

## 2023-06-02

I did have the problem again today !
After a `pct reboot 110`, I was unable to ssh into it.

`pct enter 110` did work, sshd was failed, restarted it (already a bit strange)…

but more importantly, from off2, `nc -vz 10.1.0.110 22`  did not work, nor `nc -vz 10.1.0.110 80`  while nginx was running on ct 110. `ping 10.1.0.110` was working ok.

Finally I did a `ping 10.0.0.2` from inside ct 110… and everything works again.

## 2023-06-12

Problem appeared today again…

On off2, suddenly, 110 seems to be unreachable from 101.
This made an alert to be notified: *opff-org is down*.
The site did display a gateway timeout.

Pinging 101 from 110 did return opff website, but not the mongodb (off3) connection (no product found on the web page, slow to load, because it wait for mongodb connection to timeout).
And pinging `10.0.0.3` from inside 110 did not work.

On 110, running,
`sudo ip link set arp off dev eth0 ; sudo ip link set arp on dev eth0`
which reset ARP cache tables did fix it. So this really seems to be a problem with ARP.