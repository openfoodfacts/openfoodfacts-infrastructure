# 2025-08-20 Hetzner-02 reverse proxy install

The reverse proxy is the first necessary container on Hetzner-02.

It's also the occasion to develop ansible playbook to install it.

## Creating containers using Ansible

I was unsure if I should do this step using Ansible, but finally I did !

I developed the proxmox_containers role for that.

This role use some tricks though:
1. it uses a persistent SSH connection with specific options to tunnel access to the proxmox API,
   so that proxmox actions can be run from the local machine, making it easier to handle dependencies.
2. it uses proxmox_pct connection plugin to
   create the config-op user on newly created container, with ssh keys,
   and install sudo.

It did take a bit of time to debug all this, in particular,
I had a misleading error message about TLS failure to validate certificate,
while the real problem was about the node name being wrong,
I documented it in the [README of proxmox_containers role](../../ansible/roles/proxmox_containers/README.md).

I did create an access token using my user in Proxmox (in Datacenter, API Tokens).
It's very important NOT to check the "privilege separation" option,
otherwise we would need to reconfigure every privilege for this token.


Also, there where quite a few quirks in using comunity.proxmox roles.

* If you just give it a storage and a size for rootfs,
  it should create a volume but it did not work (maybe because of the update ? I'm not sure)

  * It led me to create the volume first using ZFS,
    but I had to discover so attributes that proxmox is setting on containers datasets.
    One way to get them is, using an existing container volume,
    is to run `zfs get all <volume-path>|grep local`
    (as ZFS indicates those properties were locally modified).
    See: `ansible/roles/proxmox_containers/tasks/create_container.yml`

* To avoid complex ansible processing, I created a filter to process container arguments.
  See `plugins/filter/proxmox.py`

* I still have a bug because the community.proxmox.proxmox role
  always says that the container has changed, but I don't know why.
  I would need to investigate.
  This lead to a container restart every time we run the recipe,
  this is quite annoying.

* I had difficulties with the network, because I wanted to use the seconde ethernet card
  and I though I could just declare a bridge without IP
  and use the bridge in my container, but of course it did not work
  (but it took time to realize that).


## Asking for an IP address

Hetzner servers comes with only one IP address per server.

But the reverse proxy needs its own private address.

To get a new IP, I go in server management in robot `https://robot.hetzner.com/server`,
on hetzner-02 server, and IPs tab.

After that, as the IP is not use on the same link as the first,
it's important to ask for a specific MAC.

This MAC is to be used in ifnet definition as hwaddr for the container.
(see `ansible/host_vars/hetzner-02/proxmox.yml`)

## Installation of the reverse proxy

Thomas had created a reverese proxy role for the monitoring container
but this is based upon docker and this makes things a bit complex
for normal sys admins,
while different sys admins are interacting with it.

So I renamed reverse-proxy role to reverse_proxy_docker and created a reverse_proxy_nginx role.

I also developed the git_based_config_symlinks plugins module to keep things easier
as we try to understand which links to create / remove in configurations
(instead of a lot of complicated Jinja2 expressions).

### Creating DNS name

For now I didn't automate DNS handling,
although there seems to exist an [ansible module for OVH DNS](https://github.com/gheesh/ansible-ovh-dns)

I created a hetzner-02-proxy.openfoodfacts.org pointing to hetzner-02-proxy IP address.