# Folksonomy API

Folksonomy is a service to allow contributors to freely add labels and values to products.

The code is at

## Deployment

Folksonomy is deployed on a LXC container.

It is started thanks to a systemd unit.

It is served behind the [NGINX reverse proxy](./)


## Usefull commands

See logs:
```bash
sudo journalctl -u folksonomy
```