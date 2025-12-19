# Creation of GPU VM on Google Cloud

## Rationale

We need GPUs for running machine learning models. Currently, many machine learning models are run on osm45 GPU VM, which contains 2 x NVIDIA GTX 1080 Ti GPUs.

However, this GPU model is old and required us to install an old Triton version (23.05) and to export to ONNX IR 8 (see [the installation report of osm45](./2025-07-08-osm45-gpu-passthrough.md)). Not all models are compatible (for instance, Tensorflow SavedModel could not be loaded).

Consequently, we decided to change the GPUs to newer ones. In the meantime, we want to migrate the models to a new server. We chose to use Google Cloud (thanks to the Google Cloud credits we have).

## Creation of the VM

Name: off-gpu-01
Zone: europe-west1
2 x NVIDIA T4 GPU
8 vCPU, 32 GB RAM
OS: Debian 11, with Deep Learning VM (Deep Learning VM with CUDA 12.4 M129)

We couldn't choose Debian 12, as it is not available with Deep Learning VM.

## Server configuration

Once first launched, we accept running the NVIDIA driver installation script.

I (Raphaël) created the `config-op` user and added my public key to `/home/config-op/.ssh/authorized_keys`, as described in the [Ansible README](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/ansible/README.md).

I also added the server in the Ansible inventory file with its IP address (`ansible/inventory.production.ini`) under the `gpu-01` name.

Then I configured the server with Ansible:

```bash
ansible-playbook jobs/configure.yml -l gpu-01
```

```bash
ansible-playbook sites/triton_gpu.yml
```

An error occurred after running the task "Enable backport repository". It looks like backports are not available anymore for Debian 11. I added a `when` condition to skip this task on Debian 11 and some older versions of Debian.

Then I re-ran the playbook again.

I then created a `triton_gpu.yml` site and a `triton_gpu` role.

The `triton_gpu.yml` playbook does the following:

- install Docker
- run the `triton_gpu` role
- run the `stunnel` role

The `triton_gpu` role does the following:

- create the `off` user
- install git and uv
- clone the `robotoff` repository
- create a .env file in the `models` subfolder
- configure the docker container runtime using `nvidia-ctk`, so that docker can use the GPUs

We also install stunnel using ansible (`stunnel` role) so that communication between the gpu-01 server and the rest of the infrastructure is encrypted. We use the same triton-psk.txt key as on osm45.

I pushed [a commit](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/2c4e50c0e5cd58f0710e75f19ac0a7ba8d98e5e4) from the gpu-01 machine to save stunnel config.

Before launching the triton server, we start by donwloading the models (with the `off` user).

```bash
cd /home/off/triton-org/models
uv run manage.py download-models
```

We also copy the Triton model configuration files to the `triton` directory (read by Triton):

```bash
uv run manage.py copy-config
```

Then, we can launch the triton server:

```bash
docker compose up -d
```

and check that it is running:

```bash
docker logs triton-triton-1
```

I also disabled (by commenting the entry) a cron job added by Google Cloud Compute to diagnose the GPU status, that produces a lot of emails:

```bash
sudo crontab -e
```