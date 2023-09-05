# Munin

We use munin to monitor some of our servers.

It is available at https://www.computel.fr/munin/openfoodfacts

It can help you understand problems that occurs on the server.

Munin also sends alerts messages to off@openfoodfacts.org.

## How to configure a server

You must install the munin-node package and extra plugins on the server:

```
sudo apt install munin-node munin-plugins-extra
```

You then configure in `/etc/munin/munin-node.conf`.
The best is to have the config in this repository and symlink it:
```bash
rm /etc/munin/munin-node.conf && \
ln -s /opt/openfoodfacts-infrastructure/confs/<YOUR-SERVER>/munin/munin-node.conf /etc/munin/
systemctl restart munin-node
```


Look at other conf for munin, eg. `confs/off2/munin/munin-node.conf`.
