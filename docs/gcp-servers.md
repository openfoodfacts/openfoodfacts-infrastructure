# Google Cloud Platform servers

We have one GCP server:

- `monitoring-01`, managed using [Ansible](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/ansible)
- `gpu-01`, managed using Ansible as well. This is used to run [Triton Inference Server](https://openfoodfacts.github.io/robotoff/explanations/triton/) with GPUs for Robotoff and Open Prices ([install report](./reports/2025-10-15-gcloud-gpu-install.md)).

## GCP Firewall

There is a firewall between internet and our GCP servers.

To enable `HTTP` and `HTTPS` traffic, it is **necessary** to
tick the `Allow HTTP traffic` and `Allow HTTPS traffic` boxes in the VM settings.
