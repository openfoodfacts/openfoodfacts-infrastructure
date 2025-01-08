# 2025-01-08 Rename o*f-new

When we installed the new instances for obf/opf/opff, we named the new instances with a -new name.

This causes problem for certain systemd services uses the hostname to get the environment files.
The trick was to create a folder with the new name and a symlink to the configuration file.
This remains a quirk in current installation.

So to do some cleanup, we will:
* rename the old instances with a -old suffix
* rename the new instances to remove the -new suffix

# Renaming old instances

We are speaking of containers 110, 111, 112

First, using proxmox interface,
I saw in options that those old containers are still set to *start at boot*.
So I unset the option.

Then I go to DNS and change the hostname to add a `-old` suffix.

# Renaming new instances

We are speaking of containers 116, 117, 118

I still use the proxmox interface, but I do one by one:
* rename the container to remove the `-new` suffix
* reboot the container
* verify the website still function (after some time)
* use `systemctl status` to check everything is running
  (along with `sudo systemctl list-units --state=failed`)
* remove the /o*f-new directory in the container

# Annex making sytemd status running

While at it, looking at systemctl status, the following services are failed:
* sys-kernel-config.mount
* systemd-journald-audit.socket
and it's perfectly normal because we didn't gave capabilities for that to LXC
(would need capabilities `sys_rawio` and `audit_read`)
Thanks to [this blog post](https://www.enricobassetti.it/2023/05/proxmox-lxc-systemd-and-linux-capabilities/),
I infer that he best way to deal with it is not to disable thoses services,
but to drop capabilities for the container.
