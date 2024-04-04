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

### More plugins

To get zfs plugins we have to install contrib plugins.

Clone In `/opt`:
```bash
sudo git clone git@github.com:munin-monitoring/contrib.git munin-contrib

sudo mkdir -p /usr/local/munin/lib/
sudo ln -s /opt/munin-contrib/plugins /usr/local/munin/lib/
```


#### ZFS plugins

Activate zfs by linking. We prefer to keep the standard directory as a link
```bash
# activate zfs_arcstats zfs_cache_efficiency zpool_capacity and zpool_iostat
sudo ln -s /usr/local/munin/lib/plugins/zfs/{zfs_arcstats,zfs_cache_efficiency,zpool_capacity,zpool_iostat} /etc/munin/plugins/
sudo systemctl restart munin-node
```

#### NGINX plugins

```bash
# activate nginx-cache-hit-rate nginx_error nginx_memory nginx_connection_request
sudo ln -s /usr/local/munin/lib/plugins/nginx/{nginx-cache-hit-rate,nginx_error,nginx_memory,nginx_connection_request} /etc/munin/plugins/
sudo systemctl restart munin-node
```