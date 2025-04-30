# Sanoid

We use [Sanoid](https://github.com/jimsalterjrs/sanoid/) to:
- automatically take regular snapshots of ZFS Datasets
- automatically clean snapshots according to a retention policy
- sync datasets between servers thanks to the `syncoid` command

## sanoid snapshot configuration

`/etc/sanoid/sanoid.conf` contains the configuration for sanoid snapshots.
That is how frequently you want to do them, and the retention policy (how much to keep snapshots).

See [reference documentation](https://github.com/jimsalterjrs/sanoid/wiki/Sanoid)

There are generally two kind of templates:
- one for datasets that are synced from a different server.
  In this case we don't want to create snapshots as we already receive the one from source.
  We only want to purge old snapshots.
- one for datasets where the source is this server.
  In this case we want to regularly create snapshots and purge old ones.

We then have different retention strategies based on the type of data.

### Dealing with vzdump snapshots

vzdump snapshots are created by Proxmox during backups.
It always have the same name but is created and destroyed each time.

This can come in the way of syncoid:
If the ZFS dataset is synchronized while vzdump snapshot is present,
then on next sync it may fail, because vzdump snapshot will be a different snapshot on the source. Blocking the sync and requiring human intervention (see [How to resync ZFS replication](./how-to-resync-zfs-replication.md)).

To prevent this, we have a script (`sanoid_post_remove_vzdump.sh`) that remove vzdump snapshots on the destination (backup side) after running sanoid (post_snapshot_script). It is configured in "synced" templates in sanoid.conf,
with `post_snapshot_script = /opt/openfoodfacts-infrastructure/scripts/zfs/sanoid_post_remove_vzdump.sh`

## sanoid checks

We have a timer/service sanoid_check that checks that we have recent snapshots for datasets.
This is useful to verify sanoid is running, or syncoid is doing it's job.

The default is to check every ZFS datasets, but the one you list with `no_sanoid_checks:`
in the comments of your `sanoid.conf` file.
You can put more than one dataset per line, by separating them with ":".

For example:
```conf
# no_sanoid_checks:rpool/logs-nginx:
# no_sanoid_checks:rpool/obf-old:rpool/opf-old:
```

In case of problem, see [How to resync ZFS replication](./how-to-resync-zfs-replication.md)


## syncoid service and configuration

Sanoid does not come with a systemd service for syncoid,
so we created one, see: `confs/common/systemd/system/syncoid.service`

The syncoid service can synchronize *to* or *from* a server.

But it is always preferred to be in pull mode.
The idea is to avoid having elevated privileges on the distant server. So if an attacker gains privilege access on one server, it can't gain access to the other server (and eg. remove or encrypt all data, including backups).
* We use a user named <server_name>operator (eg. off2operator) on the remote server we want to pull from
* We use [zfs allow command](https://openzfs.github.io/openzfs-docs/man/8/zfs-allow.8.html) to give the `hold,send` permissions to this user

The service simply use each line of `/etc/sanoid/syncoid-args.conf` as arguments to `syncoid` command.


## getting status

You can use :
`systemctl status sanoid.service` and `systemctl status syncoid.service` to see the logs of last synchronization.

Also you can list snapshot on source / destination ZFS datasets to see if there are recent ones:
`/usr/sbin/zfs list -t snap <pool>/<dataset/path>`

## Ansible install

We have a sanoid ansible role that can be used to install sanoid on a server.

It use the [git based configuration](./explain-server-config-in-git.md)
for the sanoid.conf and syncoid-args.conf files,
enabling easy modifications directly on the server, after first install.

## Manual install

Sanoid is installed by using the official repository, building the deb and installing it.

It provides a sanoid systemd service and a timer unit that just have to be enabled.

For syncoid to be launched by systemd, we created a service ([see syncoid service and configuration](#syncoid-service-and-configuration)).
This service is declared as a dependency of the sanoid so that it runs just after it.

### How to build and install sanoid deb

See [install documentation](https://github.com/jimsalterjrs/sanoid/blob/master/INSTALL.md#debianubuntu).
I exactly follow the instructions.

```bash
cd /opt
git clone https://github.com/jimsalterjrs/sanoid.git
cd sanoid
# checkout latest stable release (or stay on master for bleeding edge stuff, but expect bugs!)
git checkout $(git tag | grep "^v" | tail -n 1)
ln -s packages/debian .
apt install debhelper libcapture-tiny-perl libconfig-inifiles-perl pv lzop mbuffer build-essential git
dpkg-buildpackage -uc -us
sudo apt install ../sanoid_*_all.deb
```

then [enable sanoid service](#how-to-enable-sanoid-service)

### How to enable sanoid service

Create conf for sanoid and link it

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/$SERVER_NAME/sanoid/sanoid.conf /etc/sanoid/
```


```bash
for unit in email-failures@.service sanoid_check.service sanoid_check.timer sanoid.service.d; \
  do ln -s /opt/openfoodfacts-infrastructure/confs/off1/systemd/system/$unit /etc/systemd/system ; \
done
systemctl daemon-reload
systemctl enable --now  sanoid_check.timer
systemctl enable --now  sanoid.service
```


### How to enable syncoid service

Create conf for syncoid and link it

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/$SERVER_NAME/sanoid/syncoid-args.conf /etc/sanoid/
```

Enable syncoid service:
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/$SERVER_NAME/systemd/system/syncoid.service /etc/systemd/system
systemctl daemon-reload
systemctl enable --now  syncoid.service
```

### How to setup synchronization without using root

Say we want to pull data from zfs-hdd, zfs-nvme and rpool for PROD_SERVER to BACKUP_SERVER

#### creating operator on PROD_SERVER

```bash
OPERATOR=${BACKUP_SERVER}operator
adduser $OPERATOR
# choose a random password (pwgen 16 16) and discard it

# copy public key
mkdir /home/$OPERATOR/.ssh
vim /home/$OPERATOR/.ssh/authorized_keys
# copy BACKUP_SERVER root public key

chown $OPERATOR:$OPERATOR -R /home/$OPERATOR
chmod go-rwx -R /home/$OPERATOR/.ssh
```

Adding needed permissions to pull zfs syncs

1. if you use `--no-sync-snap`, you only use `hold,send`
   ```bash
   # choose the right dataset according to your needs
   zfs allow $OPERATOR hold,send zfs-hdd
   zfs allow $OPERATOR hold,send zfs-nvme
   zfs allow $OPERATOR hold,send rpool
   ```

2. otherwise you'll need , you need `destroy,hold,mount,send,snapshot`
   ```bash
   # choose the right dataset according to your needs
   zfs allow $OPERATOR destroy,hold,mount,send,snapshot rpool
   ```

#### test connection on BACKUP_SERVER

On BACKUP_SERVER, test ssh connection:

```bash
OPERATOR=${BACKUP_SERVER}operator
ssh $OPERATOR@<ip or host>
```

#### config syncoid

You have sanoid running on the $PROD_SERVER, and creating snapshot for the dataset you want to backup remotely.

You have sanoid and syncoid already configured on BACKUP_SERVER.

We can now add lines to `syncoid-args.conf`, on BACKUP_SERVER
they must use the `--no-privilege-elevation` and `--no-sync-snap` options
(if you want to create a sync snap,
you will have to also grand snapshot creation to $OPERATOR user on $PROD_SERVER).

Use `--recursive` to also backup subdatasets.

Don't forget to create a sane retention policy (with `autosnap=no`) in sanoid on $BACKUP_SERVER to remove old data.

**Note:** because of the 6h timeout, if you have big datasets, you may want to do the first synchronization before enabling the service.

**Important:** try to have a good hierarchy of datasets, and separate what's from the server and what's from other servers.
Normally we put other servers backups in a off-backups dataset. It's important not to mix it with backups dataset which is for the server itself.
