# Virtiofs

Virtiofs is a software installed on a host that enables mounting host folders directly in a QEMU VM.
It is officially supported since [Proxmox 8.4](https://forum.proxmox.com/threads/proxmox-ve-8-4-released.164820/)

## Why is it useful ?

When you use QEMU, you usually use a ZFS Volume instead of a ZFS Dataset.
A ZFS Volume is a ZFS managed block device that does not directly support directories and files,
but instead acts as a raw support you have to format with a filesystem like ext4.
You still get the ability to snapshot and sync ZFS Volumes,
but you can't mount them on the host, hindering the possibility to see the files,
also a ZFS Volume can only be accessed by one VM.
Compare that with container that can bindmount datasets, eventually share them,
and files are immediately accessible from the host:
* making debugging tasks or data transfer far easier
* as well as enabling access to files when the container is down

With Virtiofs we can have the same features as bind mount, in VM.

We need to use VM for docker compose deployment
because containers with docker compose inside are not supported by proxmox.

## How we use Virtiofs

We use Virtiofs to have the docker volumes of our docker compose deployments in specific ZFS Datasets

In ansible, there are a [virtiofs](../../ansible/roles/virtiofs.md) and [virtiofs_mounts](../../ansible/roles/virtiofs_mounts.md) roles.

The first, declares a virtiofs mount at proxmox level (run on the host).

The second mounts the virtiofs in a VM.

Typically as our VM are for docker compose deployment,
we mount a virtiofs at `/var/lib/docker/volumes`.

As Virtiofs is really a view on the host folder, it also sees the mounted filesystem.
So if we want to separate data for a specific volume (eg. a database data),
we can create a child Dataset.

Sometimes, most data is on HDD but we want some data on NVME,
in this case we can create a ZFS dataset on a NVME based Zpool,
but change its mountpoint to be mounted as a child of the HDD dataset.

<a id="inter-zpool-mounts"/>

### Important note when you mount datasets from another zpool

ZFS normally orders mounts based on their hierarchy,
but it does so **only for datasets that are in the same zpool**

Hopefully there is a tool to do "inter"-zpool mount ordering,
named [`zfs-mount-generator`](https://openzfs.github.io/openzfs-docs/man/v2.4/8/zfs-mount-generator.8.html)
(which is generally active on proxmox, part of `zfsutils-linux`)

To use it:
* ensure `zfsutils-linux` and `zfs-zed` packages are installed:
  ```bash
  apt install zfsutils-linux zfs-zed
  ```
* the `zfs-mount-generator` needs to have information
  about the zpool at boot time, before they are active.
  For this, it needs files named `/etc/zfs/zfs-list.cache/<zpool-name>`
  containing the state of each zpool.
  To have it, you need to:
  * ensure that zed is running (`systemctl status zfs-zed.service`),
    it is provided by the `zfs-zed` package
  * ensure you have the `/etc/zfs/zed.d/history_event-zfs-list-cacher.sh` zedlet,
    normally provided by the same `zfs-zed` package.
    It will update the zpool state cache every time it changes.
  * ensure you have a `/etc/zfs/zfs-list.cache/` directory, as it is not created by default,
    and prevent state save: `mkdir /etc/zfs/zfs-list.cache`
  * regenerate the state cache of it zpool.
    For this:
    1. touch `/etc/zfs/zfs-list.cache/<pool_name>`
    2. do a property change (and undo it) on a dataset of the zpool
       to force re-creation by zed (eg `atime=on` then `atime=off`)

  Ensuring all this in one script:
  ```bash
  sudo apt install zfsutils-linux zfs-zed
  mkdir /etc/zfs/zfs-list.cache
  for POOL in $(zpool list -o name -H); \
  do \
    touch /etc/zfs/zfs-list.cache/$POOL
    # we switch atime on / off to trigger cache generation
    zfs set atime=on $POOL; \
    zfs set atime=off $POOL; \
    echo "$POOL ========="; \
    ls -l /etc/zfs/zfs-list.cache/$POOL; \
    echo "==========="; \
  done
  ```


When all this is done, to ensure your child dataset is mounted after its parent,
you have to add a  `org.openzfs.systemd:requires-mounts-for` property to the child,
with the parent dataset mount path (that is the value of its `mountpoint` property).

For example: `zfs set org.openzfs.systemd:requires-mounts-for=/zfs-hdd/virtiofs/qm-201/docker-volumes`

to ensure datasets are mounted in the right order,
otherwise next reboot will [lead to complicated situation](../../reports/2026-07-01-openprices-down.md).
