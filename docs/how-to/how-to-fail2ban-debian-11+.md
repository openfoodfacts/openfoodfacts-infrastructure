# How to install fail2ban on debian 11+

On debian 11+ (but not Proxmox version),
NFTables is used instead of iptables.

But fail2ban is not configured out of the box to use NFTables.

To do so, following https://wiki.meurisse.org/wiki/Fail2Ban#nftables more or less

Add a nftables table, to do so we will add an include for nftables:

```bash
mv /etc/nftables.conf{,.distrib}
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/nftables.conf
mkdir /etc/nftables.conf.d
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/nftables.conf.d/fail2ban.conf /etc/nftables.conf.d/

systemctl restart nftables
```


Configure fail2ban to use nftables rule, and fail2ban table:
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/action.d/nftables-common.local /etc/fail2ban/action.d/
# also override the fail2ban nftables action so that it handles ip interval like 10.0.0.0/24
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/action.d/nftables.local /etc/fail2ban/action.d/
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/jail.d/use-nftable.local /etc/fail2ban/jail.d/
```

Make fail2ban service to wait for nftables:
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/systemd/fail2ban.service.d /etc/systemd/system/

systemctl daemon-reload
systemctl restart fail2ban
```

## Seeing it in action

If you have ip in a jail
```bash
fail2ban-client status
fail2ban-client status <jail-name>
```

You should see it in the corresponding addr_set elements (`addr-set-<jainame>`):

```bash
# all rules
nft list ruleset
# more precise: fail2ban table
nft list table inet f2b-table
# more precise: fail2ban addr_set
nft list set inet f2b-table addr-set-<jail-name>
```

## For iptables lovers

If you use nftables but still better know iptables,
the `iptables-translate` command can help you.

On way to test it locally is to run it in docker:
```bash
docker run --rm --name test-deb -ti debian:12 bash
apt update && apt install iptables
# example:
iptables-translate -A INPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT
# nft 'add rule ip filter INPUT ct state established counter accept'
```