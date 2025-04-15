# How to use fail2ban to ban bots

## Configure fail2ban

```bash
sudo apt install fail2ban
```

On debian 11, also follow [How to install fail2ban on debian 11+](./how-to-fail2ban-debian-11+.md)

## Configuring some filters

We normally install those filters, with standard configurations:

* `nginx-botsearch` (banning bots that blindly search for old software install)
* `nginx-http-auth` (banning bots making too much failed auth attempts)
* `sshd` (for ssh connections)
* `proxmox_ui` (for Proxmox web interface)

## Configuring a jail for manual ban

We can create a new jail to ban bots from using our web services.

In practice, we will use the nginx-botsearch filter on a fake log file,
and add ips manually to the jail with a permanent bantime.

Enable fail2ban nginx-manual-ban jail with our specific configuration:
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/jail.d/nginx-manual-ban.local /etc/fail2ban/jail.d/
systemctl restart fail2ban
```

**Note:** fail2ban (in recent version) is naturally persistent across reboot. For that it uses a sqlite database in `/var/lib/fail2ban/`.


## Using it

### Status and logs

Like `git status`, status command are always useful when playing with fail2ban. A quick look at the logs is also interesting.

```bash
fail2ban-client status # Allow to see all the jails currently running

fail2ban-client status sshd # Allow to status for a specific jail: banned addresses, etc.

tail -f /var/log/fail2ban.log # check last entries of fail2ban logs
```

### See banned ips

```bash
sudo fail2ban-client status nginx-manual-ban
```

### Ban an ip

```bash
sudo fail2ban-client set nginx-manual-ban banip <IP>
```

Note that it supports ip ranges, like `123.456.789.1/24`

### Unban an ip
```bash
sudo fail2ban-client set nginx-manual-ban unbanip <IP>
```

If ip is part of a range, the whole range must be unbanned.
