# Pre-requisites

## Pre-requisites to run playbooks

In order to use this repo, you need:

* to have a personal GPG key
* to have an account on [github](https://github.com) and to have added your ssh key to that account
* to ask a teammate to add your GPG key to [git-crypt](./git-crypt.md) (this will allow you to decrypt secrets)
* to ask a teammate to add yout github account to `group_vars/all/sshd.yml` and run the `jobs/configure` playbook (this will authorize your ssh public key on all servers for the service account `config-op`)

Before running the playbooks, you need to use git-crypt to unlock secrets.

# Additional pre-requisites to bootstrap a server

To bootstrap a new server you need to:

* create a `config-op` user on the server
* grant the debian user sudoer rights (without password)
* have your ssh public key in `config-op` user `authorized_keys`
* add the new server to the `inventory.production.ini` file and run the `jobs/configure` playbook 
