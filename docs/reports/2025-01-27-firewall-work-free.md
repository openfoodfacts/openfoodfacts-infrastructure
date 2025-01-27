# Work on firewall (free)

I had to work a bit on the firewall to put better rules in place.

## Some pre-requisites

`iptables-persistent` must be installed

Here we use `iptables` interface to netfilter. But we could use nftables instead (which is more easy to read and configure).

But I was conservative for the hosts.

## Creating rules

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
