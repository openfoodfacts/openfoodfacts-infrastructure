# Proxmox Containers management

This roles handles containers and VM creations.

## SSH tunneling of the API

We want to avoid accessing to the proxmox API using the public IP
(because we would like to block it in the future),
at the same time, because proxmox.community modules have python packages dependencies,
it's better to run them locally
(otherwise we need those dependencies on the remote host,
while it's forbidden on debian to use pip system wide
and installing modules using apt may not bring the right version).

So we use a ssh tunnel to the API.
This is made possible by adding a:

```ini
ansible_ssh_common_args = '-L {{ proxmox_api_local_port }}:127.0.0.1:8006'
```

for proxmox node group in ansible inventory,
and by adding a `proxmox_api_local_port` variable
with a unique port for each proxmox host.

This also needs to have a persistent ssh connection,
so in ansible.cfg:

```ini
[ssh_connection]
# These settings create a persistent SSH socket that can be reused
# We need this because we would like to use ssh tunneling
# to access proxmox API
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
control_path = ~/.ansible/cp/ansible-ssh-%%h-%%p-%%r
```

## Creating containers

If you create containers there are a few points important to mention:

1. you must add your container to inventory first
2. you must add a
   `host_vars/<container_name>/<container_name>_secrets.yml`
   file with the `ansible_become_password`
   and `ansible_user_password_salt` **secret** variables

## Troubleshooting

### 596 Errors during TLS negotiation

If you get an error "596 Errors during TLS negotiation",
it might be misleading.
We ask not to verify the certificate,
so the error does not come from using a self-signed certificate,

But it may comes from the node name which is wrong !
It must be the exact same name as the node in proxmox !
[seen here](https://community.home-assistant.io/t/proxmox-failing/233988/11)

### No authentication methods available

`community.proxmox.proxmox_pct_remote` uses ssh to connect to the proxmox node.
Therefor, it needs your private key. If your key as a default name (such as `id_ed25519`),
this should work without problems. However, if not, you might need to add the following
parameter to your command:

```sh
ansible-playbook [...] --extra-vars "ansible_paramiko_private_key_file=/path/to/your/key"
```
