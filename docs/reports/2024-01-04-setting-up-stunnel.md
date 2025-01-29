
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
  * and made it private `chmod -R go-rwx /etc/stunnel/psk/`
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

## 2023-02-08 MongoDB get hacked!

I did change the configuration for the stunnel entrance not to be exposed on public IP, but it seems it was not taken into account (maybe I did not restart stunnel service correctly)… and thus our MongoDB stunnel access was expose to the wild web… where some hacker immediately take our database and drop it to ask for money against retrieval…

Luckily Gala noticed rapidly and Stephane identified that mongo was exposed through our proxy1 ip address.

We have the data in the sto, so it's not the end of the world but still it's very annoying.
Unfortunately I did not already setup auto snapshotting (because I was seeing mongodb data as transient)

I rsync data from off3 again (dating 3h before) and lose updates to the mongodb for 3h but got the mongodb up again quickly.

But I took the decision:

* to move client stunnel to a separate container with no risk of exposition
* to snapshot mongodb data because restoring from sto would take long so it's a big annoyance


## Creating stunnel client container

We followed usual procedure to [create a proxmox container](../proxmox.md#how-to-create-a-new-container):
* of id 113
* choosed a debian 11
* default storage on zfs-hdd (for system) 6Gb, noatime
* 2 cores
* memory 512 Mb, no swap

I also [configured email](../mail.md#postfix-configuration) in the container.


## Setting up stunnel on ovh1 stunnel-client

Did the same as above to [set up stunnel on ovh1 proxy](#setting-up-stunnel-on-off1-proxy).

I created a key with `ssh-keygen -t ed25519 -C "off@stunnel-client.ovh.openfoodfacts.org"` 
add it as a deploy key to this projects 
and cloned the project in `/opt` so that I can use git for modified configuration files.

I created my configs and symlinked them.
Then:
```bash
systemctl daemon-reload
systemctl start stunnel@off
systemctl enable stunnel@off
```

I tested it from staging mongo container (see [Testing stunnel for mongodb](#testing-stunnel-for-mongodb))


## Changing services config

On VM docker-prod (200), I changed the .env for off-query-org and robotoff-org.
Then for both services I did a "docker-compose down && docker-compose up -d".

I also pushed a [commit to robotoff](https://github.com/openfoodfacts/robotoff/commit/ade67c21bab152afe64c33b9f540bf91b212efb0) and a [PR to off-query](https://github.com/openfoodfacts/openfoodfacts-query/pull/32) to change the configuration.

## Removing stunnel client on ovh reverse proxy

On the reverse proxy I kept stunnel but I removed the config for MongoDB.
