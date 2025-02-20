# 2025-01-27 Work on firewall (free)

I had to work a bit on the firewall to put better rules in place.

## Some pre-requisites

`iptables-persistent` must be installed

Here we use `iptables` interface to netfilter. But we could use nftables instead (which is more easy to read and configure).

But I was conservative for the hosts.

## Listing Open Ports

It's better to see what's running on the machine before creating rules.

You can use the `netstat` command (`apt install net-tools` if needed).

`netstat -pantu|grep LISTEN` can help

We only care about publicly exposed ports, as for internal traffic, we will allow any, for now.

## Creating ipv4 rules

Note: For simplicity I will use the "-A" (append) option,
but in reality, as some rules were already in place,
I did use the -I (insert) option, to place them at the right position.

Established connections are accepted:
```
-A INPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
```
Loop back is ok:
```
-A INPUT -i lo -j ACCEPT
```
Local trafic is ok:
```
-A INPUT -s 10.1.0.0/16 -j ACCEPT
```

icmp is accepted:
```
-A INPUT -p icmp -j ACCEPT
```

Ports we want to accept connections on
```
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 8006 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
```

We also have specific rule for Munin-node, where it's deployed, allowing only a specific ip (munin server) to access:
```
-A INPUT -s xx.xx.xx.xx -p tcp -m tcp --dport 4949 -j ACCEPT
```

Note that we also add a masquerading rule in nat table:
```
-t nat -A POSTROUTING -s 10.1.0.0/16 -j MASQUERADE
```


We then save with `iptables-save`
```bash
iptables-save > /etc/iptables/rules.v4.new
```
I then edited the file to pass to DROP policy.

And apply with iptables-apply (which will rollback change in case of problems)
```bash
iptables-apply /etc/iptables/rules.v4.new
```

When it's ok, I moved the new file:
```bash
mv /etc/iptables/rules.v4{.new,}
```


## ipv6 rules

Established connections are accepted:
```
-A INPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
```
Loop back is ok:
```
-A INPUT -i ::1 -j ACCEPT
```
Local trafic is ok:
```
-A INPUT -s fd28:7f08:b8fe::/64 -j ACCEPT
```

icmp is accepted but **IMPORTANT** it's icmpv6 :
```
-A INPUT -p icmpv6 -j ACCEPT
```

Ports we want to accept connections on
```
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 8006 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
```

Note that we also add a masquerading rule in nat table (here for off2):
```
-t nat -A POSTROUTING -s fd28:7f08:b8fe::/48 -o vmbr0 -j MASQUERADE
```

We then save with `ip6tables-save`
```bash
ip6tables-save > /etc/ip6tables/rules.v6.new
```
I then edited the file to pass to DROP policy.

And apply with iptables-apply (which will rollback change in case of problems)
```bash
ip6tables-apply /etc/iptables/rules.v6.new
```

When it's ok, I moved the new file:
```bash
mv /etc/iptables/rules.v6{.new,}
```

## verifying

We can use `nmap` to verify. just use it with the ip (and eventually -6 for ipv6), and it will list open ports.


## Side note:

We also disabled rcpbind.service on off1 and off2.
