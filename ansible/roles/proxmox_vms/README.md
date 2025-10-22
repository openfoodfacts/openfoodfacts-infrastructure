# Proxmox VMS management

**:bomb: THIS ROLE IS NOT YET READY:**
Is this worth writing this role.
Ain't it a bit dangerous to be able to change VMs characteristics maybe without being aware of it (see the update_unsafe)

We only support creation based upon the existence of a template VM
which must support cloud-init.


## SSH tunneling of the API

See README.md in proxmox_containers.

## Creating vms

**FIXME** review

If you create vms there are a few points important to mention:

1. you must add your container to inventory first
2. you must add a
   `host_vars/<container_name>/<container_name>_secrets.yml` 
   file with the `ansible_become_password`
   and `ansible_user_password_salt` **secret** variables
