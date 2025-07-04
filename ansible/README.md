# Open Food Facts Ops using Ansible

This folder contains ansible automation for Open Food Facts servers.

## Pre-requisite

- git
- python3 (>3.7)
- pip
- virtualenv

### Installation by Platform

#### Debian-based Linux

```bash
sudo apt install git python3 python3-pip python3-venv
```

#### OSX

```bash
brew install git python
python3 -m ensurepip --upgrade
pip3 install virtualenv
```

#### Windows (using WSL)

```bash
sudo apt install git python3 python3-pip python3-venv
```

### Install git-crypt

See [Install of git-crypt](./docs/git-crypt.md)

## Setup

Clone the infrastructure repository and go in the ansible sub-folder:

```bash
git clone git@github.com:openfoodfacts/openfoodfacts-infrastructure.git
cd openfoodfacts-infrastructure/ansible
```

Create and activate virtual environment:

```bash
python3 -m venv ./venv
source venv/bin/activate
```

Install dependencies

```bash
python3 -m pip install -r requirements.pip
ansible-galaxy install -r requirements.yml
```

If you want to add [autocompletion](https://docs.ansible.com/ansible/devel/installation_guide/intro_installation.html#adding-ansible-command-shell-completion) for ansible commands:

```bash
python3 -m pip install argcomplete
activate-global-python-argcomplete --user
```

Finally [Setup git-crypt](./docs/git-crypt.md).

## Usage

### Pre-requisite to use playbooks

See [Pre-requisites](./docs/pre-requisites.md)

### Verify Installation

```bash
ansible all -m ping
```

### Common Tasks

### Prepare a new host server

If you are about to install a new host server (proxmox host, or standalone server),
you must install debian.

Then generate a random password.
Put that password as value for `ansible_become_password` in `host_vars/<server-name>/<server-name>-secrets.yml`.

Then ssh to the new server to add config-op user:

```bash
GITHUB_USER_NAME=<your-github-username>
adduser config-op
# use created password
adduser config-op sudo
# add your public key
mkdir /home/config-op/.ssh
curl https://github.com/$GITHUB_USER_NAME.keys >> /home/config-op/.ssh/authorized_keys
chmod go-rwx -R /home/config-op/.ssh
chown config-op:config-op -R /home/config-op/.ssh
```

Test you can connect to the new server using config-op user:

```bash
ssh config-op@<server-ip>
```

#### Configure Servers

```bash
ansible-playbook jobs/configure.yml
```

or for a specific server:

```bash
ansible-playbook jobs/configure.yml -l <server-name>
```

#### Deploy Monitoring

```bash
ansible-playbook sites/monitoring.openfoodfacts.org.yml
```

#### User Management

##### Add New User

1. Edit `group_vars/all/system-users.yml` to add user to `system_users_github_authorized_users` with state 'present'.
   Set if he is super_user, that means it has access to host and sudo access.
2. Run:
   ```bash
   ansible-playbook jobs/configure.yml
   ```

##### Revoke User Access

1. Edit `group_vars/all/system-users.yml` to
   change `state` to `absent` for the user in `system_users_github_authorized_users`
2. Run:
   ```bash
   ansible-playbook jobs/configure.yml
   ```

## Ansible folder structure

```
├── docs                                # Documentation in Markdown
│   ├── index.md
│   ├── *.md
│   └── ...
├── group_vars                          # Configuration per group
│   ├── all                             # Common configuration
│   │   ├── base.yml
│   │   └── sshd.yml
│   ├── group-1
│   │   ├── config.yml                  # Configuration of group in plain text
│   │   └── secret.yml                  # Configuration of group encrypted
│   └── group-X.yml                     # Configuration of group in a single file
├── host_vars                           # Configuration per host
│   ├── server-XX.yml
│   └── server-YY.yml
├── jobs                                # Maintenance tasks as playbooks
│   ├── configure.yml
│   └── ...
├── plugins                             # Ansible plugins
│   ├── filters
│   ├── lookup
│   └── ...
├── roles                               # Ansible roles
│   ├── role-X
│   └── ...
├── sites                               # Ansible playbooks to deploy sites
│   ├── public.url.yml
│   └── ...
├── .gitattributes                      # Specifies (among others) the files to encrypt
├── .gitignore                          # Files ignored by git
├── ansible.cfg                         # Ansible configuration for this repository
├── inventory.production.ini            # Ansible inventory: all servers are there
├── requirements.pip                    # Python dependencies
└── requirements.yml                    # Ansible dependencies
```

## Contributing

Please use ansible-lint before submitting a PR.

### Variables management

It can be difficult in ansible to understand where a variable is defined,
and where it is used.

In this repository we will try to follow the following rules:

- a role declares all the variables it uses in `defaults/main.yml`.
  This is the interface of the role.
- variables use a prefix using role name (eg: for sshd role, use `sshd_` prefix.)
- secret always add the prefix `vault_` and must be encrypted with ansible-vault

## Known issues

- When executing an `ansible` command, if you are getting the following error:
  ```
  ERROR! 'utf-8' codec can't encode character '\udcba' in position 11: surrogates not allowed
  ```
  you might have forgotten to run `git-crypt unlock`
