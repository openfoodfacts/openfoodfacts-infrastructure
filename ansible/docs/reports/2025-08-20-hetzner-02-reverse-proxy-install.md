# 2025-08-20 Hetzner-02 reverse proxy install

The reverse proxy is the first necessary container on Hetzner-02.

It's also the occasion to develop ansible playbook to install it.

## Creating containers using Ansible

I was unsure if I should do this step using Ansible, but finally I did !

I developed the proxmox_containers role for that.

This role use some tricks though:
1. it uses a persistent SSH connection with specific options to tunnel access to the proxmox API,
   so that proxmox actions can be run from the local machine, making it easier to handle dependencies.
2. it uses proxmox_pct connection plugin to create the config-op user on newly created container.

It did take a bit of time to debug all this, in particular,
I had a misleading error message about TLS failure to validate certificate,
while the real problem was about the node name being wrong,
I documented it in the [README of proxmox_containers role](../../ansible/roles/proxmox_containers/README.md).

I did create a access token using my user in Proxmox (in Datacenter, API Tokens).
It's very important NOT to check the "privilege separation" option,
otherwise we would need to reconfigure every privilege for this token.

## Asking for an IP address

Hetzner servers comes with only one IP address per server.

But the reverse proxy needs its own private address

## Installation of the reverse proxy

Thomas had created a reverese proxy role for the monitoring container
but this is based upon docker and this makes things a bit complex
for normal sys admins,
while different sys admins are interacting with it.

So I renamed reverse-proxy role to reverse_proxy_docker and created a reverse_proxy_nginx role.

I also developed the git_based_config_symlinks module to keep things easier to read in tasks
(instead of a lot of complicated Jinja2 expressions).

### Creating DNS name

For now I didn't automate DNS handling,
although there seems to exist an [ansible module for OVH DNS](https://github.com/gheesh/ansible-ovh-dns)

I created a hetzner-02-proxy.openfoodfacts.org pointing to hetzner-02-proxy IP address.