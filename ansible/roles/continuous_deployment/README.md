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

The private / public key might be saved in the shared KeepassXC file.


## Note on testing connection

If you want to test the connection is ok, with the private key,
you have to remember that `-i` option only applies to the final connection,
not the proxy jump connection.

So you have to either configure the proxy connection in your .ssh/config,
or specify the whole proxy command.
Something like:
```bash
ssh -F /dev/null \
  off@10.13.1.200 -o "IdentitiesOnly=yes"  -i ~/.ssh/test-key \
  -o "ProxyCommand=ssh -i ~/.ssh/test-key -o IdentitiesOnly=yes -W %h:%p off@scaleway-02.infra.openfoodfacts.org"
```