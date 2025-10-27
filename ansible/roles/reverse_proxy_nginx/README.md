# NGINX reverse proxy role

This is a very simple role that will:

- get nginx installed from the debian packaging system
- add prometheus exporter

## Nginx Configuration

The nginx configuration of is stored in this repository, in `confs/<ct_inventory_name>/nginx`.

## Certbot setup

**Before** adding a Nginx configuration for your website, you must request a certificate using certbot with
the following command:

```sh
sudo certbot --nginx -d <domain_name>
```
