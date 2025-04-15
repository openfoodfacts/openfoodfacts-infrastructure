# 2024-11-15 Create clone of opff container for Keycloak testing

We need a container with a test instance of Product Opener to test the new Keycloak based authentication.

## Approach 1: clone current opff container

Instead of reinstalling a Product Opener instance from scratch (as we did for [New install of OBF on OFF2 with new generic code](./2024-04-26-off2-obf-new-install.md) ), I will clone the current opff-new clone into opff-test.

In the Proxmox web interface, I clone ct 118 opff-new into 119 opff-test.
I get the message: "unable to clone mountpoint 'mp0' (type bind) (500)"

https://forum.proxmox.com/threads/unable-to-replicate-mountpoint-type-bind-500.45785/

Trying to skip replication through the Proxmox web interface results in an error:
"Permission check failed (mount point type bind is only allowed for root@pam) (403)"

Editing /etc/pve/lxc/118.conf on off2 host directly instead:
mp0: /zfs-hdd/opff,mp=/mnt/opff,replicate=0

But we still get the same error when cloning.

## Approach 2: backup current opff container and restore it on new container

I'm going to try another way, by a doing a backup of 118 and restoring it in a new container.

In the Proxmox web interface, the last backup was on 2024-10-28, so I create a new backup.

After talking with Alex:
- We have decided to stop using backups as everything is on ZFS.
- So instead of using the backup / restore approach, I will try creating a new container and use ZFS to clone the opff-new container.

## Approach 3: create a new container and use zfs clone

### Create container 119

In proxmox web interface, I create container 119, opff-test.

Resulting config:

```cat /etc/pve/lxc/119.conf 
arch: amd64
cores: 4
features: nesting=1
hostname: opff-test
memory: 6000
net0: name=eth0,bridge=vmbr1,firewall=1,gw=10.0.0.2,hwaddr=0A:89:FC:99:1A:38,ip=10.1.0.119/24,type=veth
ostype: debian
rootfs: zfs-hdd:subvol-119-disk-0,size=30G
swap: 0
unprivileged: 1
```

I do not start the container.

### Copy container 118 config and files to container 119

We want to replace zfs-hdd/pve/subvol-119-disk-0 with the content of zfs-hdd/pve/subvol-118-disk-0

So we will do a snapshot of zfs-hdd/pve/subvol-118-disk-0 and clone it.

We have existing snapshots:

```
zfs list -t snapshot | grep subvol-118 | tail -n 5
zfs-hdd/pve/subvol-118-disk-0@autosnap_2024-11-22_07:00:42_hourly                         2.39M      -     7.25G  -
zfs-hdd/pve/subvol-118-disk-0@autosnap_2024-11-22_08:01:11_hourly                         2.47M      -     7.25G  -
zfs-hdd/pve/subvol-118-disk-0@autosnap_2024-11-22_09:01:55_hourly                         2.21M      -     7.25G  -
zfs-hdd/pve/subvol-118-disk-0@vzdump                                                      2.14M      -     7.25G  -
zfs-hdd/pve/subvol-118-disk-0@autosnap_2024-11-22_10:01:11_hourly                            0B      -     7.25G  -
```

But we will create a new snapshot, so that we don't clone a snapshot managed by sanoid, that sanoid will want to delete later.

```
zfs snapshot zfs-hdd/pve/subvol-118-disk-0@cloned-for-opff-test-119_2024-11-22
zfs list -t snapshot | grep subvol-118 | grep cloned
zfs-hdd/pve/subvol-118-disk-0@cloned-for-opff-test-119_2024-11-22                         1.51M      -     7.25G  -

zfs clone zfs-hdd/pve/subvol-118-disk-0@cloned-for-opff-test-119_2024-11-22 zfs-hdd/pve/subvol-119-disk-0-clone-from-118 
```

I can now destroy original volume:
```bash
zfs destroy -r zfs-hdd/pve/subvol-119-disk-0

```
cp /etc/pve/lxc/118.conf /etc/pve/lxc/119.conf
```

```
vi /etc/pve/lxc/119.conf
```

changing:

hostname: opff-test
rootfs: zfs-hdd:subvol-119-disk-0-clone-from-118,size=30G
net0: name=eth0,bridge=vmbr1,firewall=1,gw=10.0.0.2,hwaddr=0A:89:FC:99:1A:38,ip=10.1.0.119/24,type=veth

I then start container 119, it starts correctly.

## Container configuration

# proxy configuration

We will use the new.openpetfoodfacts.org site to point to the new container:

in the 101 proxy container, change the IP:

vi /etc/nginx/sites-enabled/new.openpetfoodfacts.org 

3 lines:

proxy_pass http://10.1.0.119:80;

systemctl restart nginx

# changing log files to have different log files than the current opff-new 118 container

in container 119, we change the log files names to have opff-test:

nginx:

```
        access_log /var/log/nginx/static-opff-access.log proxied_requests buffer=256K
 flush=1s;
        error_log /var/log/nginx/static-opff-error.log;

                access_log /var/log/nginx/proxy-opff-test-access.log proxied_requests
 buffer=256K flush=1s;
                error_log /var/log/nginx/proxy-opff-test-error.log;
```

apache:

ErrorLog /srv/opff/logs/opff_test_error_log
CustomLog /srv/opff/logs/opff_test_access_log combined

```bash
root@opff-test:/mnt/opff/logs# mkdir opff-test
root@opff-test:/mnt/opff/logs# chown -R off:off opff-test

root@opff-test:/srv/opff# ls -lrt | grep logs
lrwxrwxrwx  1 off off     23 Aug 30 10:53 logs -> /mnt/opff/logs/opff-new
root@opff-test:/srv/opff# rm logs
root@opff-test:/srv/opff# ln -s /mnt/opff/logs/opff-test logs
root@opff-test:/srv/opff# chown off:off logs

root@opff-test:/var/log# ls -lrt | grep apache2
lrwxrwxrwx 1 root  root                26 Aug 30 10:53 apache2 -> /mnt/opff/logs/apache2-new
root@opff-test:/var/log# ls /mnt/opff/logs/apache2-new/^C
You have new mail in /var/mail/root
root@opff-test:/var/log# mkdir /mnt/opff/logs/apache2-test
root@opff-test:/var/log# rm apache2
root@opff-test:/var/log# ln -s /mnt/opff/logs/apache2-test apache2
```

## Starting Apache

Apache fails to start:

root@opff-test:/srv/opff# systemctl restart apache2
Job for apache2.service failed because of unavailable resources or another system error.
See "systemctl status apache2.service" and "journalctl -xe" for details.

```bash
journalctl -xe
░░ 
░░ The job identifier is 1883.
Nov 22 10:52:50 opff-test bash[1008]: Unit apache2-opff-test.service could not be fo>

root@opff-test:/srv# mkdir opff-test
root@opff-test:/srv# mkdir opff-test/env
root@opff-test:/srv# ln -s /srv/opff/env/env.opff /srv/opff-test/env/env.opff-test
```

This is because I named the host opff-test, and we use the host name in the environment file:
/etc/systemd/system/apache2.service.d/override.conf

[Service]
# Apache needs some environment variables like PRODUCT_OPENER_FLAVOR_SHORT
# %l is the short host name (e.g. off, obf, off-pro)
EnvironmentFile=/srv/%l/env/env.%l

Hack to fix it (already used for opff-new):

```bash
cd /srv/
mkdir opff-test
mkdir opff-test/env/
ln -s /srv/opff/env/env.obf /srv/opff-test/env/env.opff-test
```

systemctl restart apache2

https://world.new.openpetfoodfacts.org works.  (I changed the top bar color to green to make it more obvious that the site is different)

## Configuring for Keycloak

```
 cd /srv/opff
 sudo su
```

### Stop current service

```
systemctl stop apache2
```

### Stash current config changes

```
exit
sudo su off
git stash save "opff new config"
```

### Switch code to keycloak branch

```
git switch keycloak
perl scripts/build_lang.pl
```

### Re-apply config changes

```
git stash apply
```

### Configure keycloak variables

The following new environment variables need to be set (in env/env.opff):

```
KEYCLOAK_BASE_URL=https://auth.openfoodfacts.org
KEYCLOAK_BACKCHANNEL_BASE_URL=http://10.1.0.104:5600
KEYCLOAK_REALM_NAME=open-products-facts

PRODUCT_OPENER_OIDC_CLIENT_ID=ProductOpener
PRODUCT_OPENER_OIDC_CLIENT_SECRET=< Available in the Keycloak deployment >
PRODUCT_OPENER_OIDC_DISCOVERY_ENDPOINT=http://10.1.0.104:5600/realms/open-products-facts/.well-known/openid-configuration
```

Added following to Config2.pm and exported:

```
%oidc_options = (
	client_id => $ENV{PRODUCT_OPENER_OIDC_CLIENT_ID},
	client_secret => $ENV{PRODUCT_OPENER_OIDC_CLIENT_SECRET},
	discovery_endpoint => $ENV{PRODUCT_OPENER_OIDC_DISCOVERY_ENDPOINT},
	# Keycloak specific endpoint used to create users. This is currently required for backwards compatibility with apps
	# that create users by POSTing to /cgi/user.pl
	keycloak_base_url => $ENV{KEYCLOAK_BASE_URL},
	keycloak_backchannel_base_url => $ENV{KEYCLOAK_BACKCHANNEL_BASE_URL},
	keycloak_realm_name => $ENV{KEYCLOAK_REALM_NAME}
);
```

Add and export %oidc_options in Confirm_opff.pm

### Install any new Perl libraries

```
exit
sudo su
export PERL5LIB=/srv/opff/lib
apt install -y libanyevent-redis-perl libssl-dev
cpanm --notest --quiet --skip-satisfied --installdeps .
```

...

### Migrate users

```
exit
sudo su off
export PERL5LIB=/srv/opff/lib
source env/setenv.sh opff
perl scripts/migrate_users_to_keycloak.pl
```

Got error 

```
There was an error importing users to Keycloak. Please ensure that the client has permission to manage the realm. This is not enabled by default and should only be a temporary permission. {client_id => "ProductOpener",keycloak_realm_name => "open-products-facts",response => "Can't connect to auth.openfoodfacts.org:443 (Connection refused)\n\nConnection refused at /usr/share/perl5/LWP/Protocol/http.pm line 50.\n"}
```
Fixed by changing backchannel URL to http://10.1.0.104:5600

Next error:
```
There was an error importing users to Keycloak. Please ensure that the client has permission to manage the realm. This is not enabled by default and should only be a temporary permission. {client_id => "ProductOpener",keycloak_realm_name => "open-products-facts",response => "{\"error\":\"HTTP 403 Forbidden\"}"}
```
Need to add permissions to the user - need to check what these are.

Was able to migrate a single user with
```
perl scripts/migrate_users_to_keycloak.pl api-single users/johngom.sto
```
Added manage-realm permission to the ProductOpener user and seemed to fix it.

Stared import at Sat Nov 23 13:08:56 2024

Keycloak process got killed after a few users. Try api-multi.

[Sat Nov 23 13:15:48 2024] Started

Multiple messages about invalid field length for username:

{"field":"username","errorMessage":"error-invalid-length","params":["username",2,20]}

Also 

{"errorMessage":"User exists with same email"}
{"field":"email","errorMessage":"error-invalid-email","params":["email","dunensue@ gmail.com"]}

[Sat Nov 23 14:11 2024] 60,000 users imported
[Sat Nov 23 16:04 2024] 200,000 users imported


### Update Keycloak configuration

ProductOpener client configuration redirect URL needs to include:

`https://world.new.openpetfoodfacts.org/cgi/oidc_signin_callback.pl`

Also need signout callback.

### Start services and test

```
systemctl start apache2
```

### Testing Redis

Needed to add the following to Config_opff.pm:

```
$redis_url = $ProductOpener::Config2::redis_url;
```

Then run script manually:

```
perl scripts/listen_to_redis_stream.pl
```

#### User registration

Got email verification but no logo.
On clicking link displays invalid_grant but second click shows email is validated

```
User registered {newsletter => "subscribe",user_id => "johngomtest"}
No Minion backend configured in lib/ProductOpener/Config2.pm
[Mon Nov 25 11:53:01 2024] listen_to_redis_stream.pl: EV: error in callback (ignoring): Can't call method "enqueue" on an undefined value at /srv/opff/lib/ProductOpener/Minion.pm line 88.
```

#### User Deletion

As expected:
```
User deleted {user_id => "johngomtest"}
No Minion backend configured in lib/ProductOpener/Config2.pm
[Mon Nov 25 12:03:46 2024] listen_to_redis_stream.pl: EV: error in callback (ignoring): Can't call method "enqueue" on an undefined value at /srv/opff/lib/ProductOpener/Minion.pm line 88.
```

### Observations

Account console not working - think it is to do with cookies and setting up forwarded headers with the nginx proxy

Fixed by adding `--proxy-headers xforwarded` to Keycloak startup.

Need to build languages. Fixed

## Refreshing from branch

```
git stash save "opff new config2"
git pull
git stash apply

# Add following to Config2.pm and export:
$process_global_redis_events = 1;

# And following to Config_opff.pm and export:
$process_global_redis_events = $ProductOpener::Config2::process_global_redis_events;

source env/setenv.sh opff
export PERL5LIB=/srv/opff/lib
perl scripts/build_lang.pl

exit
cd /srv/opff
sudo su
systemctl stop apache2
systemctl start apache2

ln -s /srv/opff/conf/systemd/minion@.service /etc/systemd/system
systemctl daemon-reload
# Updated log path for minion-log.conf
systemctl start minion@opff.service

ln -s /srv/opff/conf/systemd/redis_listener@.service /etc/systemd/system
systemctl start redis_listener@opff.service
```

Noticed that with `systemctl status redis_listener@opff.service` there was no mention of connecting to Redis. Starting the script directly with:

```
export PERL5LIB=/srv/opff/lib
source env/setenv.sh opff
perl scripts/listen_to_redis_stream.pl
```

Shows: 

```
Starting listen_to_redis_stream.pl
Trying to reconnect to Redis
init_redis {redis_url => "10.1.0.122:6379"}
Reading from Redis {streams => ["BLOCK",0,"STREAMS","user-deleted","user-registered","\$","\$"]}
Connected to Redis
```
It looks like the service is working though