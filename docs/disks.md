# Disks

## Some good practices

Always try to separate: primary data, cache data (data generated from primary data), configuration data, and system.
This makes data management (backup, recovery, day to day maintenance) easier.

In ZFS use different datasets for that.

For backup data or large data with few I/O operations eventually use NFS mount from a separate server.


## ZFS

we extensively use ZFS, see [ZFS overview](./zfs-overview.md)

## Disk space

See [How to add disk space on a Qemu VM](./how-to-add-disk-space-on-qemu.md)

## Smartctl

Some useful command:

```bash
smartctl -x
```

gives you every informations about a system.

Be attentive to `SMART overall-health self-assessment test result`.

Also verify `Device Error Count`. (you can see errors with `smartctl -l error`)

Verify that tests under `SMART Extended Self-test` finished. (you can see tests with `smartctl -l selftest`)

Use `smartctl -t short /dev/sdX` to test a single device. (or `-t long`)

Resources: 
* (fr) https://www.malekal.com/smartctl-verifier-son-disque-en-ligne-de-commandes-linux/ 
* about unreadable sectors https://www.truenas.com/community/threads/is-this-a-bad-sign-smartd-1-currently-unreadable-pending-sectors.9824/#post-42966

