# Google Cloud Platform servers

We have one GCP server:

- `monitoring-01`, managed using [Ansible](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/ansible)

## GCP Firewall

There is a firewall between internet and our GCP servers.

To enable `HTTP` and `HTTPS` traffic, it is **necessary** to
tick the `Allow HTTP traffic` and `Allow HTTPS traffic` boxes in the VM settings.
