
## 2024-01-04 Setting up stunnel

Robotoff and openfoodfacts-query needs access to mongodb to get data. But we want to secure access to it.

## Setting up stunnel on off1 proxy

On the reverse proxy container:
* installed stunnel package (which is a proxy to stunnel4)
* I had to override the systemd unit file to add RuntimeDirectory, Group and RuntimeDirectoryMode so that pid file could be added correctly by users of group stunnel4
* created `/etc/stunnel/off.conf` - we will only have one instance for many services, no need of specific services
  * run in foreground, so that systemd handles the process
  * specify user and group stunnel4
  * specify pid file according to systemd unit RuntimeDirectory
  * added a mongodb service, for first tests.
* created `/etc/stunnel/psk/mongodb-psk.txt`
  * and made it private `chown -R go-rwx /etc/stunnel/psk/`
  * To create a password I used `pwgen 32` on my laptop

* enable and start service:
  ```bash
  systemctl enable stunnel@off.service
  systemctl start stunnel@off.service
  ```

All (but the psk files which are not to be committed) is part of [commit d797e7c73](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/d797e7c7329c3c789ff21dc63ebbf1753aa4a376)



Note: `dpkg-query -L stunnel4` helps me locate `/usr/share/doc/stunnel4/README.Debian` that I read to better understand the systemd working. Also `/usr/share/doc/stunnel4/examples/stunnel.conf-sample` is a good read for the global section, while configuration example with PSK is available here: https://www.stunnel.org/auth.html

## Setting up stunnel on ovh1 proxy

On the reverse proxy container:
* installed stunnel package (which is a proxy to stunnel4)

* This is a older version of the package than on so systemd is not integrated, so I added systemd units myself

* created `/etc/stunnel/off.conf` - we will only have one instance for many services, no need of specific services
  added a mongodb service, for first tests.
* created `/etc/stunnel/psk/mongodb-psk.txt`
  * and made it private `chown -R go-rwx /etc/stunnel/psk/`
  * with the user / password created on off1 proxy
* enable and start service:
  ```bash
  systemctl enable stunnel@off.service
  systemctl start stunnel@off.service
  ```

All (but the psk files which are not to be committed) is part of [commit 086439230](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/086439230a41f4d94755276610cbab838ad96f4a)


## Testing stunnel for mongodb

On each server, I can use : `journalctl -f -u stunnel@off` to monitor activity.hostname()

On off staging VM:
```
cd /home/off/mongo-dev
sudo -u off docker-compose exec mongodb bash
mongo 10.1.0.101
> db.hostInfo()["system"]["hostname"]
mongodb
```

and (after a lot of tribulations…) it worked !!!

## Note: problem reaching 10.0.0.3 from off2 proxy (not useful right now)

At a certain point, by mistake, I used 10.0.0.3 server for mongodb target.

But from the proxy this is unreachable… this is because there is no route to this host.

To add the route we can do
```bash
ip route add 10.0.0.0/24 dev eth0 proto kernel scope link src 10.1.0.101
```
To make it permanent we can add an executable `/etc/network/if-up.d/off-servers-route.sh` file, with:
```bash
#!/bin/bash

if [[ $IFACE == "eth0" ]]; then
	  # we want to access off1 and off2 from this machine
	  ip route add 10.0.0.0/24 dev $IFACE proto kernel scope link src 10.1.0.101
fi
```

But as right now this is not needed (new mongo is in 10.1.0.102 which is reachable), **I didn't do it**.
