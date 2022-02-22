# Proxmox

On ovh1 and ovh2 we use proxmox to manage VMs.

**TODO** this page is really incomplete !

## HTTP Reverse Proxy

The VM 101 is a http / https proxy to all services.

It as a specific network configurations with two ethernet address:
* one internal, to communicate with other VMs
* one which is bridged on host network card, with ip fail over mechanism.

**Important**: only the public ip should have a gateway [^proxmox_multiple_gateway]

To make a new service, hosted on proxmox, available you needs to:
* have this service available on proxmox internal network
* write a configuration on nginx for this service
* in the DNS, CNAME you service name to `proxy1.openfoodfacts.org`

Most of the time https certificates are managed on the proxy VM.

[^proxmox_multiple_gateway]: The default proxmox interface does not offer options to indicate which gateway should be the default gateway, and the public ip needs to have its gateway as the default one, and there is no trivial way to achieve this reliably and elegantly, thus the best solution is to have only one gateway. See also [ovh reverse proxy incident of 2022-02-18](./reports/2022-02-18-ovh-reverse-proxy-down.md)

## Storage

We use two type of storage: the NVME and zfs storage.
There are also mounts of zfs storage from ovh3.

**TODO** tell much more

## Creating a new VM

**TODO**