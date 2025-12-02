# 2025-11-27 Moving keycloak to scaleway

Keycloak is currently on off1.

We want to move it to scaleway-01.

It is currently using docker compose, running on a CT on proxmox.

As they have been recent problem with this approach on Proxmox 9.1,
I prefer to go for a VM as recommended by Proxmox.
Also now that we have VirtioFS enabling direct write to ZFS Datasets,
one important drawback is removed.

## Creating the VM for docker on scaleway-01

I will create a VM on scaleway-01 to use docker.

I will use ansible recipe for that.

I will create a VM 200 and name it scaleway-docker-prod

- I added the server to inventory, in scaleway_vms group
- I added the scaleway-docker-prod-secrets in it's host vars to define the become password
FIXME: to be continued !

## Using stunnel to connect to Postgres on off2

FIXME