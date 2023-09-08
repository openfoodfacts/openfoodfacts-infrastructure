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
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/jail.d/use-nftable.local /etc/fail2ban/jail.d/
```

Make fail2ban service to wait for nftables:
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/systemd/fail2ban.service.d /etc/systemd/system/

systemctl daemon-reload
systemctl restart fail2ban
```
