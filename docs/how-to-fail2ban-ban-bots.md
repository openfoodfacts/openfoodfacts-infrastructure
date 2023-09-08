# How to use fail2ban to ban bots

## Configure fail2ban

```bash
sudo apt install fail2ban
```

On debian 11, also follow [How to install fail2ban on debian 11+](./how-to-fail2ban-debian-11+.md)


## Configuring nginx-botsearch.conf

We can use nginx-botsearch jail to ban bots to use our web services.

In practice, we will use manual ban, with a permanent bantime.

Enable fail2ban nginx-botsearch with our specific configuration:
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/jail.d/nginx-botsearch.local /etc/fail2ban/jail.d/
systemctl restart fail2ban
```

**Note:** fail2ban (in recent version) is naturally persistent across reboot. For that it uses a sqlite database in `/var/lib/fail2ban/`.


## Using it

### See banned ips
```bash
sudo fail2ban-client status nginx-botsearch
```

### Ban an ip
```bash
sudo fail2ban-client set nginx-botsearch banip <IP>
```

### Unban an ip
```bash
sudo fail2ban-client set nginx-botsearch unbanip <IP>
```