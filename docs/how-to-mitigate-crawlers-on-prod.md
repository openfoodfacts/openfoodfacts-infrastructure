# How to mitigate crawlers in case of too much traffic

It happens that some program is hammering Open Food Facts, causing serious latency and 504 problems to every users.

Most of the time it's someone who is not aware data must be downloaded at https://world.openfoodfacts.org/data instead of harvesting.

## Find disturbing IPs

On prod server we have a script `concatenate_by_ip.pl`.

Go to access log for your site.

```bash
tail -n 100000 access_log |  ./concatenate_by_ip.pl|tail -n 10
```

Shows you a list of IP addresses with a number of requests

```bash
tail -n 100000 access_log | grep <ip_adress>
```
to see activity of a single ip address and try to understand what's going on.

Search and facets requests are the most consuming.
(Product read requests are just a read of a file)

## Warn

If the User-Agent has some indication on who is using the platform, try to contact them.


## Blacklist

### On off2 reverse proxy

```bash
fail2ban-client set nginx-botsearch banip <IP>
```

see [How to use fail2ban to ban bots](./how-to-fail2ban-ban-bots.md)

### On off1

In case it's needed, blacklist the IP address using an iptables rule:

`iptables -A INPUT -s <ip_address> -j DROP`

## Make it better

We could instead implement traffic rate limitation using NGINX.
