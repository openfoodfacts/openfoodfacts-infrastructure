# Moji Datacenter

Through Open Street Map, we have a new server hosted by [Moji](https://moji.fr/).
The server is located in Paris.

Informations about the server can be found on the Open Street Map [wiki](https://wiki.openstreetmap.org/wiki/FR:Serveurs_OpenStreetMap_France/Moji).

## Servers

The server is a Dell T630 with 2 1080Ti GPUs, 128GB of RAM, 56 cores, 1x 8TB NVMe, 8x 8TB HDD.
Proxmox 8.2 was installed by Christian on the server.

### Network

Currently, the server does not have a public ipv4 address, only an ipv6 one (2a06:c484:5::45).

To connect to the server, you must either first connect to the proxy server (45.147.209.254) that has a public ipv4 or use the VM/CT ipv6 address.