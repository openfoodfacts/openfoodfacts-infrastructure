# Continuous Deployment Role

Creates a user (called `off` by default) and adds a SSH public key to its `authorized_keys`.
Those are used to setup a CI/CD using GitHub Actions.

## Setup a new node

To setup a new node, create a file called `host_vars/<node_name>/continuous-deployment.yml` with the following variable:

```yml
continuous_deployment__ssh_public_keys:
  - "ssh-ed25519 AAAAC3Nz[...] off@<node_name>"
```

The SSH public keys put in this are used to authenticate the deployer users.
The corresponding private key should be added to the GitHub Actions secrets
(use a different key for each repository).

A public/private keypair can be generated with

```sh
ssh-keygen -t ed25519 -C "off@<node_name>"
```
