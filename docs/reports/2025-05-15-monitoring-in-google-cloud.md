# Moving Monitoring to Google Cloud

We decided to move our monitoring to Google Cloud, so that it's on an external data-center,
and does not go down with one of our servers as today on ovh1.

It will also free some space on ovh1, which is currently full.

## Creating the server in google cloud

We provisioned a VM in Google Cloud in "robotoff" project, with 160GB of disk space.

## Adding a disk

Elasticsearch backups are quite big, so we added a 300G disk to the VM.

To do that, goes on the VM in Google Cloud, click on "modify", and then add another disk.

As it's just for backups, we just added a one zone standard persistent disk.

This disk is immediately available as `/etc/sdb`.

We will make it a zpool volume so that it's easier to sync on other servers.

