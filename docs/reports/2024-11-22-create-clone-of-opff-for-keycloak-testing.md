# 2024-11-15 Create clone of opff container for Keycloak testing

We need a container with a test instance of Product Opener to test the new Keycloak based authentication.

Instead of reinstalling a Product Opener instance from scratch (as we did for [New install of OBF on OFF2 with new generic code](.2024-04-26-off2-obf-new-install.md) ), I will clone the current opff-new clone into opff-test.

In the Proxmox web interface, I clone ct 118 opff-new into 119 opff-test.
I get the message: "unable to clone mountpoint 'mp0' (type bind) (500)"

https://forum.proxmox.com/threads/unable-to-replicate-mountpoint-type-bind-500.45785/

Trying to skip replication through the Proxmox web interface results in an error:
"Permission check failed (mount point type bind is only allowed for root@pam) (403)"

Editing /etc/pve/lxc/118.conf on off2 host directly instead:
mp0: /zfs-hdd/opff,mp=/mnt/opff,replicate=0

But we still get the same error when cloning.

I'm going to try another way, by a doing a backup of 118 and restoring it in a new container.

In the Proxmox web interface, the last backup was on 2024-10-28, so I create a new backup.


