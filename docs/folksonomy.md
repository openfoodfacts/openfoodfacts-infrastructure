# Folksonomy API

Folksonomy is a service to allow contributors to freely add labels and values to products.

The code is at [https://github.com/openfoodfacts/folksonomy_api/](https://github.com/openfoodfacts/folksonomy_api/)

## Explain Deployment

* Production instance for Folksonomy API is deployed on a LXC container.
  (108 on OVH at the time of writing)

* Staging instance is deployed the same way (container 110 on hetzner-02)

The code is in `/home/folksonomy/folksonomy_api`

It is started thanks to a systemd unit: `folksonomy.service` (config at `/etc/systemd/system/folksonomy.service`)

Server is running uvicorn on port 8000 with user folksonomy.

It is served behind the [NGINX reverse proxy](./nginx-reverse-proxy.md)

In production: 
The python environment has been setup using uv, to get python3.10 and poetry on top of that.
So poetry executable is in `/home/folksonomy/.local/bin/poetry`

In staging:
The install / deployment was realized with ansible, `sites/folksonomy_api.yml` playbook.

## How to Deploy a new version

### Using ansible

For staging, you can use the ansible playbook:
```bash
time ansible-playbook -l folksonomy-staging
```

### Manually (current production)

In production,
before every upgrade, make a snapshot of the Proxmox container. Then:

```bash
# Switch to "folksonomy" user
su - folksonomy
cd ~/folksonomy_api
# Upgrade from git repository
git fetch
git checkout vX.y.z
# Install new depencies if any
poetry install
# DB migration process
poetry run yoyo apply --database postgresql:///folksonomy
# go back root
exit
# Finally, restart the service (with root user or root rights or sudo rights)
systemctl daemon-reload
systemctl restart folksonomy
```

## Useful commands

Status (reload/restart/etc.):
```bash
systemctl status folksonomy
```

See service logs:
```bash
sudo journalctl -u folksonomy
```

## Install

### Current staging

* We created the container on hetzner-02 using ansible (part of `sites/proxmox_node.yml` playbook)
* We configured the container with `jobs/configure.yml`
* We installed folksonomy using `sites/folksonomy_api.yml` playbook

### Current production

We simply clone the repository in /home/folksonomy/folksonomy_api.

We installed the python environment with uv (because system lacked python3.10):
```bash
# as root
pip install uv
/usr/local/bin/uv python install 3.10
# as folksonomy
su - folksonomy
uv tool install poetry --python=3.10
# ensure PATH is correct
which poetry
# /home/folksonomy/.local/bin/poetry
```

The systemd unit is linked from the repository
```bash
ln -s /home/folksonomy/folksonomy_api/confs/systemd/folksonomy.service /etc/systemd/system/folksonomy.service
systemctl daemon-reload
```
