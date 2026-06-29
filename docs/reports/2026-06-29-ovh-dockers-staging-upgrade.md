# 2026-06-29 OVH Dockers staging upgrade

_Dockers staging_ (or `OVH200`) is a VM running on `OVH1`.

This report describes the upgrade of `OVH200` from Debian 11 to Debian 12.

## Making the upgrade

Here are the steps that were followed:

- Create a Proxmox snapshot of `OVH200` (without including RAM)

- Upgrade the existing packages

```sh
sudo apt update
sudo apt upgrade
sudo apt full-upgrade
sudo apt autoremove --purge
```

- Check the packages health. This shouldn't output anything.

```sh
sudo dpkg --audit
sudo apt-mark showhold
```

- Change Debian repository sources

```sh
sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
sudo sed -i '/non-free/ s/$/ non-free-firmware/' /etc/apt/sources.list
```

- List package sources to update

```sh
ls /etc/apt/sources.list.d/
```

- Change each repository sources (here is an example for `docker`)

```sh
sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list.d/docker.list
```

- Upgrade the OS (in tmux in case the SSH connection breaks)

```sh
tmux
sudo apt update
sudo apt upgrade --without-new-pkgs
sudo apt full-upgrade
```

- Reboot (this didn't work as expected, which is explained in the next part)

```sh
sudo reboot
```

- Ensure everything runs correctly

```sh
lsb_release -a
sudo systemctl list-units --state failed
sudo docker ps -a
```

- Clean up legacy packages

```sh
sudo apt autoremove --purge
sudo apt clean
```

- I also installed the QEMU Guest Agent

```sh
sudo apt install qemu-guest-agent
sudo systemctl start qemu-guest-agent
sudo systemctl enable qemu-guest-agent
```

## `OVH200` not rebooting after upgrade

For some unknown reason (probably related to the upgrade of the Linux kernel), the VM would not reboot after the upgrade.

`OVH200` was stuck looping on the boot screen (showing the Proxmox logo). Here is how it was fixed:

- In Proxmox, open the graphical console of the VM
- Press `Esc`
- Choose the Debian installer DVD: `3. DVD/CD [...] (Debian [..])`
- Choose `Advanced options`
- Choose `Rescue mode`
- Choose `Do not configure the network at this time`
- Choose the device to use as root filesystem: `/dev/sdb1`
- Choose `Execute a shell in /dev/sdb1`
- Run the following commands:

```sh
grub-install /dev/sdb
update-grub
update-initramfs -u -k all
exit
```

- Choose `Reboot the system`
