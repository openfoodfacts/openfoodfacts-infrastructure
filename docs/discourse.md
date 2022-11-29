# Discourse

[Discourse](https://www.discourse.org/) is a forum application.

It is installed on our proxmox infrastructure in a QEMU virtual machine (202)

## Software installation

Software is installed in /var/discourse.

We use the https://github.com/discourse/discourse_docker.git.

The docker configuration is contained in `config/app.yml`

It creates a unique docker container containing whole application, postgresql and redis database, and so on !

It defines volumes where all the data is found. It's in `/var/discourse/shared/standalone` and mounted in container as `/shared`

You might get a shell into the docker container using `./launcher enter app bash`.

## Mail

Mail is very important as a lot of notifications are sent by the forum.

Mail can be tested at https://forum.openfoodfacts.org/admin/email

We use [promox mail gateway](./mail.md).

**⚠ Warning:** the sender email [have to be on main domain](./mail.md#only-domain), NOT forum.openfoodfacts.org.