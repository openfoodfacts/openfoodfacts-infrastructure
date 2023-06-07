# Sanoid

We use [Sanoid](https://github.com/jimsalterjrs/sanoid/) to:
- automatically take regular snapshots of ZFS Datasets
- automatically clean snapshots thanks to a retention policy
- sync datasets between servers thanks to the `syncoid` command

## snapshot configuration

`/etc/sanoid/sanoid.conf` contains the configuration for sanoid snapshots.
That is how frequently you want to do them, and the retention policy (how much to keep snapshots).

See [reference documentation](https://github.com/jimsalterjrs/sanoid/wiki/Sanoid)

There are generally two templates:
- one for datasets that are synced from a different server.
  In this case we don't want to create snapshots as we already receive the one from source.
  We only want to purge old snapshots.
- one for datasets where the source is this server.
  In this case we want to regularly create snapshots and purge old ones.


## syncoid service and configuration

Sanoid does not come with a systemd service, so we created one, see: `confs/off2/systemd/system/syncoid.service`

The syncoid service can synchronize *to* or *from* a server.

The service simply use each line of `/etc/sanoid/syncoid-args.conf` as arguments to `syncoid` command.

## getting status

You can use :
`sytemctl status sanoid.service` and `systemctl status syncoid.service` to see the logs of last synchronization.

Also you can list snapshot on source / destination ZFS datasets to see if there are recent ones:
`sudo zfs list -t snap <pool>/<dataset/path>`

## Install

Sanoid is installed by using the official repository, building the deb and installing it.

It provides a sanoid systemd service and a timer unit that just have to be enabled.

For syncoid to be launched by systemd, we created a service ([see syncoid service and configuration](#syncoid-service-and-configuration)).
This service is declared as a dependency of the sanoid so that it runs just after it.
