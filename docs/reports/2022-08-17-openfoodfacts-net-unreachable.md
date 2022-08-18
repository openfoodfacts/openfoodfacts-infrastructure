# 2022-08-17 openfoodfacts.net unreachable

## What happens

* day before stagging (preprod) environment was down due to a bug introduced in the code
* A PR [#openfoodfacts-server:7214](https://github.com/openfoodfacts/openfoodfacts-server/pull/7214) was submitted and merged to fix it
* github action went bogus, but was reruned later and passed
* though openfoodfacts.net was unreachable

## Why this happens
* the day before, Charles saw that wiki and some other services were down and had to reboot proxy1
* openfoodfacts.net was still using the old way to redirect:
  * redirect to ovh1.openfoodfacts
  * ip filters would then forward to internal ip 101 (aka proxy VM)
* this kind of forwarding did not work any more but I don't know why
* Also this way of doing as the drawback that nginx can't see the correct incoming address, but see instead 10.0.0.1

## What was done

### Resolving by pointing to proxy1 instead of ovh1

I tested that using proxy1 address would work, using:

```
curl  --connect-to world.openfoodfacts.net:443:193.70.55.124:443 https://off:***@world.openfoodfacts.net
```

Go on OVH interface, web cloud, domain names, openfoodfacts.net, dns zones

Change `CNAME` and `A` previously pointing to ovh1 to point to proxy1

- `A` rule for: `openfoodfacts.net` and `*.openfoodfacts.net`
- `CNAME` rule for: `events.openfoodfacts.net`, `productopener.openfoodfacts.net`, `robotoff.openfoodfacts.net`

We had to wait for propagation...

On the `A` rule I changed DNS TTL to 360s as it is a test environment... (suggested by [Benoit382 on slack](https://openfoodfacts.slack.com/archives/C02KVRT2C/p1660736063583439?thread_ts=1660729404.648899&cid=C02KVRT2C))

### Trying to understand why ovh1 forwarding is down

Forwarding rule and Masquerading rule seems there:

```bash
sudo iptables -t nat -L --verbose --line-numbers

Chain PREROUTING (policy ACCEPT 3135 packets, 201K bytes)
num   pkts bytes target     prot opt in     out     source               destination         
1    3016K  180M DNAT       tcp  --  any    any     anywhere             ovh1.openfoodfacts.org  tcp dpt:https to:10.1.0.101:443
2     318K   18M DNAT       tcp  --  any    any     anywhere             ovh1.openfoodfacts.org  tcp dpt:http to:10.1.0.101:80
(...)
Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
num   pkts bytes target     prot opt in     out     source               destination         
(...)
3    2203K  150M MASQUERADE  all  --  any    vmbr1   10.1.0.0/16          anywhere            
4      10M  697M MASQUERADE  all  --  any    any     anywhere             anywhere            
5        0     0 MASQUERADE  all  --  any    vmbr1   10.1.0.0/16          anywhere            
6        0     0 MASQUERADE  all  --  any    vmbr1   10.1.0.0/16          anywhere    
```

But the proxy nginx does not seems accessible to ovh1:

`nc -vz 10.1.0.101 443` and `nc -vz 10.1.0.101 80` are not responding

While on the proxy itself, it is:

```
# nc -vz 10.1.0.101 443
proxy [10.1.0.101] 443 (https) open
```

This is linked to previous problem resolution, see [Reverse proxy down on 18 fév 2022, Final resolution](2022-02-18-ovh-reverse-proxy-down.md#final-resolution).

Solution: on proxy add a rule for routing 10.1.0.xxx packets:
```
sudo ip route add 10.0.0.0/8 dev eth0
```

Now `nc -vz 10.1.0.101 443` works from ovh1 and service is up again.