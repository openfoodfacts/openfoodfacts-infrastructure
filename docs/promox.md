# Proxmox

On ovh1 and ovh2 we use proxmox to manage VMs.

**TODO** this page is really incomplete !

## HTTP Reverse Proxy

The VM 101 is a http / https proxy to all services.

It has it's own bridge interface with a public facing ip.

See [Nginx reverse proxy](./nginx-reverse-proxy.md)

## Storage

We use two type of storage: the NVME and zfs storage.
There are also mounts of zfs storage from ovh3.

**TODO** tell much more

## Creating a new VM

**TODO** (see wiki page)

## Loggin to a container or VM

Most of the time we use ssh to connect to containers and VM.

The [mkuser](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/scripts/proxmox-management/mkuser) script helps you create users using github keys.

For the happy few sudoers on the host, they can attach to containers using `lxc-attach -n <num>` where `<num>` is the VM number. This gives a root console in the container.