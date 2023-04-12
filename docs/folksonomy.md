# Folksonomy API

Folksonomy is a service to allow contributors to freely add labels and values to products.

The code is at [https://github.com/openfoodfacts/folksonomy_api/](https://github.com/openfoodfacts/folksonomy_api/)

## Deployment

Folksonomy is deployed on a LXC container.
(108 at the time of writing)

Code is in `/home/folksonomy/folksonomy_api`

It is started thanks to a systemd unit: `folksonomy.service` (config at `/etc/systemd/system/folksonomy.service`)

Server is running uvicorn on port 8000 with user folksonomy.

It is served behind the [NGINX reverse proxy](./nginx-reverse-proxy.md)


## Useful commands

Status (reload/restart/etc.):
```bash
systemctl status folksonomy
```

See service logs:
```bash
sudo journalctl -u folksonomy
```

## Upgrade

Before every upgrade, make a snapshot of the Proxmox container. Then:

```bash
# Switch to "folksonomy" user
su folksonomy
# Upgrade from git repository
git pull
# Install new depencies if any
pip install -r requirements.txt
# Do not use in production?
pytest # should pass
# DB migration process
yoyo apply --database postgresql:///folksonomy
pytest # should pass
# Finally, restart the service (with root user or root rights or sudo rights)
systemctl restart folksonomy
```
