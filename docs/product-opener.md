# Product Opener

Product Opener is the backend that powers the Open Food Facts website and mobile apps, and
all the other siblings projects (Open Beauty Facts, Open Pet Food Facts, Open Products Facts...).

In staging, Open Food Facts is deployed on the ovh1 server (ovh1.openfoodfacts.org), in a proxmox VM (201) specific to all staging services. Other sibling projects are not deployed in staging.

In production, it's deployed on the off2 server (off2.openfoodfacts.org).
Each flavor of Open Food Facts (OFF, OBF, OPF...) is deployed in its own proxmox VM:

| Flavor | VM |
| ---- | --- |
| OPFF | 110 |
| OBF  | 111 |
| OPF  | 112 |
| OFF  | 113 |
| OFF-PRO | 114 |

The internal IP of the VMs is `10.1.0.{VMID}`.
Once connected on the off2 server,  OFF can therefore be accessed on `10.1.0.113`.

## How to connect to the server (production)

First, you need to have access to the off2 server with root access.
Once you have access, you need to create a user within the VM. This user will be used to connect to the VM.

A clone of the [openfoodfacts-infrastructure](https://github.com/openfoodfacts/openfoodfacts-infrastructure) repository is already present in `/opt/openfoodfacts-infrastructure/`. This is where all scripts and configuration files are stored.

Go to the `/opt/openfoodfacts-infrastructure/scripts/proxmox-management` to  directory and run with root privileges `./mkuseralias`. This script will ask you the name of the user you want to create and your Github ID (to add your public key registered on Github to the user's authorized keys).

Once the user is created, you can connect to the VM from off2 (proxy jump) with `ssh {user}@{VM_IP}`.

You can add the following configuration to your `~/.ssh/config` file to make it easier to connect to the VM (don't forget to replace `{user}` with the name of the user you created):

```
Host off2
    HostName off2.openfoodfacts.org
    User {user}

Host off
    HostName 10.1.0.113
    User {user}
    ProxyJump off2
```

You can now connect to the VM with `ssh off`.

## Where to find the logs/images?

Everything is stored in the `/srv/{flavor}` directory.
For example, for OFF, the directory is `/srv/off`.

All logs are stored in `./logs`, nginx logs are in `./logs/access.log` and `./logs/error.log`.
Application logs can be found in `./logs/log4perl.log`.

Images are stored in `./images/products`

## How to restart the apache server?

The apache server is managed by systemd. You can restart it with `sudo systemctl restart apache2`.

## How cron jobs are managed?

We don't use cron anymore to manage scheduled tasks, we use systemd timers instead.
You can find all the timers in `/etc/systemd/system/`.