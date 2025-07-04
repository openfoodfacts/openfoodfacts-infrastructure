# Introduction to Open Food Facts Infrastructure

Welcome to the Open Food Facts Infrastructure documentation! 
This repository is dedicated to managing the infrastructure that powers Open Food Facts and its related projects. Our goal is to provide a reliable, scalable, and secure infrastructure to support the various services and applications that make up the Open Food Facts ecosystem.


## Main Practices

### Proxmox

Proxmox is an open-source server virtualization management solution that we use extensively in our infrastructure. It allows us to manage virtual machines (VMs) and containers (CTs) efficiently. Proxmox provides a web-based interface for easy management and monitoring of our virtualized environment.

Some software is installed / deployed in containers.
Docker deployments normally use a VM.

For more details about our Proxmox setup and management, see [Proxmox](./proxmox.md).

### Server Configuration Management

We manage server configurations using Git. Each server has a clone of this repository, and configuration files are symlinked to the appropriate locations. This allows us to track changes, maintain consistency, and easily roll back to previous configurations if needed. For more details, see [Explanation on server configuration with git](./explain-server-config-in-git.md).

### Continuous Integration and Continuous Delivery (CICD)

We use a lot CICD process to automate the integration of code changes. This ensures all tests pass and desired quality standards are met. Our CICD process includes automated testing, building Docker containers, and, for some software, deploying to pre-production and production environments. For more information, see [CICD](./cicd.md).

### Docker

Docker is a one of the key component of our infrastructure. We use Docker to containerize our applications, ensuring consistency and ease of deployment. Docker Compose is used for orchestration, allowing us to manage multi-container applications with ease. For more details, 

see:
- [Docker at Open Food Facts](./docker.md).
- [Docker Onboarding](./docker_onboarding.md)
- [Docker Infrastructure](./docker_architecture.md)

### Observability


Observability (monitoring, alerts) allows us to monitor the health and performance of our systems, detect issues early, and gain insights into the behavior of our applications. We use a combination of tools and practices to achieve observability, including logging, metrics, and tracing. For more details, see [Observability](./observability.md).

We also have a [status page](https://status.openfoodfacts.org/), driven by [openfoodfacts-upptime](https://github.com/openfoodfacts/openfoodfacts-upptime)
and a [specific repository regarding monitoring](https://github.com/openfoodfacts/openfoodfacts-monitoring).

The [How to handle alerts](./how-to-handle-alerts.md) helps you diagnose and fix potential issues
that created an alert.


### ZFS

We use a lot ZFS capabilities to store data on disk, and synchronize them accross servers thanks to Sanoid.

See:
- [ZFS Overview](./zfs-overview.md): An introduction to ZFS.
- [Sanoid](./sanoid.md): Information about using Sanoid for ZFS snapshots.


## Our Servers

Our infrastructure is hosted on multiple bare metal servers.
They are grouped in different data centers, usually forming a proxmox cluster.

See [Infrastructure Overview](./overview.md)

Some servers are graciously sponsored by [Fondation Free](https://www.fondation-free.fr/) (at [Scaleway](https://www.scaleway.com/)), [OVH](https://www.ovhcloud.com) and [Moji](https://moji.fr/)

For more details about our servers and their configurations, see the following pages:

- [Free Datacenter](./free-datacenter.md)
- [OVH Servers](./ovh-servers.md)
- [Moji Datacenter](./moji-datacenter.md)
- [Hetzner Servers](./hetzner-servers.md)
- [GCP Servers](./gcp-servers.md)

### Virtual machines

See [Virtual machines](./virtual-machines.md)

## Production Architecture Overview

Our production architecture consists of different services to run Open Food Facts and sibling projects.
Those are deployed on different servers and different containers and virtual machines.

For a detailed overview of our production architecture, see [Production Architecture](./prod-architecture.md).

Other tools supporting the community are deployed in containers, some times on the same servers.

If you deploy a new service, see [How to deploy a new service](./how-to-deploy-a-new-service.md).

## Repository Structure

The repository is organized into several directories, each serving a specific purpose:

- `confs/`: Contains configuration files for various servers and services.
- `docker/`: Contains Docker-related files, including Docker Compose configurations.
- `docs/`: Contains documentation files, including this introduction.
- `docs/reports`: contains post mortem or log of installations.
- `scripts/`: Contains scripts for managing and maintaining the infrastructure.


## Services


### Important Services 

- [Mail](./mail.md): Details about our mail setup.
- [NGINX reverse proxy](./nginx-reverse-proxy.md): The reverse proxy for all services


### Services Supporting the Main Open Food Facts Deployment

- [Product Opener](./product-opener.md): Backend that powers the Open Food Facts website and mobile apps.
- [Open Food Facts Query](./openfoodfacts-query.md): Service computing aggregations.
- [Postgres](./postgres.md): Information about our PostgreSQL setup and management.
- [MongoDB](./mongodb.md): Information about our MongoDB setup and management.
- [Redis](./redis.md): Details about our Redis setup and management.
- [Producers SFTP](./producers_sftp.md): To push product updates on producer platform.
- [Folksonomy](./folksonomy.md): User editable labels and values.
- [Recipe Estimator](./recipe-estimator.md): Prototype to estimate percentages of recipes

### Tools for the Community

- [Discourse](./discourse.md): For forum.
- [Matomo](./matomo.md): For web analytics.
- [Zammad](./zammad.md): For support.
- [Odoo](./odoo.md): The CRM.

## Additional Resources

Here are some additional resources that may be of interest:

- [Disks](./disks.md): Information about disk management and best practices.
- [How to mitigate crawlers on prod](./how-to-mitigate-crawlers-on-prod.md): Guide on mitigating crawlers on production.
- [How to resync ZFS replication](./how-to-resync-zfs-replication.md): Guide on resyncing ZFS replication.
- [Linux Server](./linux-server.md): General setup for Linux servers.
- [Rclone](./rclone.md): Information about using rclone.

### Incident logs

- [Logs off1](./logs-off1.md): Incident logs for off1 server.
- [Logs off2](./logs-off2.md): Incident logs for off2 server.
- [Logs off3](./logs-off3.md): Incident logs for off3 server.
- [Logs ovh1](./logs-ovh1.md): Incident logs for ovh1 server.
- [Logs ovh2](./logs-ovh2.md): Incident logs for ovh2 server.
- [Logs ovh3](./logs-ovh3.md): Incident logs for ovh3 server.

## You are welcome to contribute

We hope you find this documentation helpful and welcoming. If you have any questions or need further assistance, please feel free to reach out to us.

Happy contributing!
