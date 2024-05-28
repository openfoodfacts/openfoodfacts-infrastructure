# 2024-02-08 Production Redis install

## Created CT

I created a CT on off2 followings [How to create a new Container](../proxmox.md#how-to-create-a-new-container):
* id 122 (off-redis)
* 20Gb disk on zfs-hdd, noatime
* added a disk on zfs-nvme mounted on /var/lib/redis/ with 5Gb size and noatime option.
* 2 Cores
* 2 Gb memory, 0B swap

I did not create a user.

I also [configure postfix](../mail.md#postfix-configuration) and [tested it](../mail.md#testing-that-the-gateway-is-well-configured).

Cloned this repository in [/opt using a root key as deploy key](../how-to-have-server-config-in-git.md)

## Installed Redis

```bash
sudo apt install redis
```

Then I changed `/etc/redis/redis.conf` to use not protected mode and bind on all interfaces.
I also moved the redis.conf file to the git repository and did a symlink in `/etc/redis` instead.

Restarted redis: `systemctl restart redis.service`

## Adding access for OVH through stunnel

On off2 reverse proxy added configuration to join redis in `/etc/stunnel/off.conf`:
```ini
# enabling connections to redis on off2
[OffRedis]
client = no
accept = 6379
connect = 10.1.0.122:6379
ciphers = PSK
# this file and directory are private
PSKsecrets = /etc/stunnel/psk/redis-psk.txt
```

create psk: `echo ovh-proxy-redis:$(pwgen 32 1) > /etc/stunnel/psk/redis-psk.txt`

On 113 container (stunnel-client) on ovh1, created the client side in `/etc/stunnel/off.conf`:
```ini
# connecting to mongodb on off1
[OffRedis]
client = yes
# expose only in private network
accept = 10.1.0.113:6379
connect = proxy2.openfoodfacts.org:6379
ciphers = PSK
# this file and directory are private
PSKsecrets = /etc/stunnel/psk/redis-psk.txt
```
The psk file contains same content as the one on off2 proxy.


## Notifications on failure

I added the `email-failures@redis.service`, and override redis configuration to send email on failure:

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/off-redis/systemd/system/email-failures\@.service /etc/systemd/system/
ln -s /opt/openfoodfacts-infrastructure/confs/off-redis/systemd/system/redis.service.d/ /etc/systemd/system/
systemctl daemon-reload
# just to be sure
systemctl restart redis
```





