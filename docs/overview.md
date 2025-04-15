# Infrastructure overview

## Locations

We have servers hosted by two providers:

- [free.org](https://www.fondation-free.fr/) is sponsoring us electricity, network and server hosting.
  We have two servers:
  - off1.openfoodfacts.org
  - off2.openfoodfacts.org

  see [Free Datacenter](./free-datacenter.md)

- [OVH foundation](https://www.ovhcloud.com/) sponsors us three bare metal servers:

  - ovh1.openfoodfacts.org
  - ovh2.openfoodfacts.org
  - ovh3.openfoodfacts.org

  See [OVH Servers](./ovh-servers.md)

- [Moji](https://moji.fr/) is also sponsoring us a good server

We also have some paid servers:
- ks1.openfoodfacts.org at [Kimsufi](./ovh-servers.md)
- some servers at [Hetzner](./hetzner-servers.md) (should be temporary)

## Network

### web traffic proxies

- Most services are hosted on ovh,
  and pass through an nginx proxy (see [proxmox - HTTP Reverse Proxy](./proxmox.md#http-reverse-proxy))
  hosted on 101 VM on ovh1 which has a bridge with it's own ip.

- product opener instances (openfoodfacts.org and its cousins) have their own proxy on [off1](#off1)
- a specific nginx is also set on [ovh3](#ovh3) to serve images and some static resources


### Stunnel

We still need to deploy stunnel for clear text tcp services transiting through
(also to avoid ip rules)

### IP tables

We limit access to certain services through IP tables rules.
Notably:
- on off2 access to mongodb is filtered by ip to enable access from ovh

We also use IP tables rules to proxy services:
Notably:
- on ovh1 ip tables rules proxy PGM service requests coming from off1 and off2 (we could replace by stunnel)


## Servers

### off1

Located at free.org

Currently installed in bare-metal mode with debian. (migration to come to proxmox)

Main services:
- Open Food Facts server main nginx (distribution install)
- all Product Opener instances: Open Food Facts / Open Products Facts / etc.

It also contains secondary services like https://cestemballepresdechezvous.fr/

### off2

Located at free.org

Currently installed in bare-metal mode with debian. (migration to come to proxmox)

Main services:
- Main MongoDB instance supporting all product data for product opener instances on [off1](#off1)

### ovh1

Located at ovh Strasbourg (sbg3)

Uses [proxmox](./proxmox.md)

Part of [proxmox](./proxmox.md) cluster.

Contains lots of small services, as proxmox containers:
- [http reverse proxy](./proxmox.md#http-reverse-proxy)
- [Proxmox mail gateway](./mail.md)
- blog
- [odoo (connect)](./odoo.md)


### ovh2

Located at ovh Roubaix (rbx8)

Part of [proxmox](./proxmox.md) cluster.

Contains two big QEMU VMs hosting lots of docker services.
One for staging, one for production.
See [Docker architecture](./docker_architecture.md)

### ovh3

Located at ovh Roubaix (rbx7)

It's a storage server, which mainly contains:
- replication of all production data: images, products, etc.
- a nginx to serve images (and some static resources as fallback)
- some zfs volumes for ovh1 and ovh2 services

### osm45 (moji)

Located at Moji. See [Moji Datacenter](./moji-datacenter.md)

IPV6 only (+ ipv4 internal network)
