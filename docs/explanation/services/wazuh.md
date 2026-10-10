# Reference documentation for the Wazuh proof of concept.

## Overview

[Wazuh](https://wazuh.com/) is a security platform combining a SIEM and an XDR
agent. We run it as a **proof of concept** to evaluate whether it gives us useful
security insight into the Open Food Facts infrastructure, given how many
servers and containers we operate.

This page documents the deployment. It is a proof of concept and is expected to
change, either by being extended into a real deployment or by being removed.

## Deployment

A single Proxmox container hosts all three central components
(the **indexer**, the **manager** and the **dashboard**) at once. This is
Wazuh's "all-in-one" topology and is the smallest thing that exercises the full
stack.

| | |
|---|---|
| Container | `wazuh`, CT 160 on `ovh2` |
| Address | `10.1.0.160` |
| Inventory group | `[aio]`, child of `[wazuh_cluster]` |
| Resources | 4 cores, 8192 MB RAM, 50 GB disk, Debian 12 |
| Playbook | `ansible/wazuh.yml` |

The container was created by hand and its setup is recorded in
[2026-10-10-wazuh-poc-install.md](../../reports/2026-10-10-wazuh-poc-install.md).
It is configured like any other container: being in `[ovh_containers]` and not
in `[non_ansible_hosts]`, it is picked up by `jobs/configure.yml`.

### How the playbook is wired

`ansible/wazuh.yml` does nothing but `import_playbook` the upstream
`wazuh-aio.yml`. We deliberately do **not** vendor a copy of it, because keeping
a fork in sync with upstream releases is a task we would consistently forget.

### Installing wazuh-ansible

`wazuh-ansible` is several roles in one repository. `ansible-galaxy` expects one
role per source and refuses it outright:

```
[WARNING]: - wazuh-ansible was NOT installed successfully: this role does not
appear to have a meta/main.yml file.
```

It is therefore vendored as a **git submodule** at `ansible/vendor/wazuh-ansible`,
and `ansible.cfg` adds its `roles/` to `roles_path`. It sits outside
`roles.galaxy/` on purpose: that directory is gitignored, and `git submodule add`
refuses to add anything under an ignored path. Keeping vendored code separate
from installer-managed directories also means `ansible-galaxy` never touches it.

It comes with the repository:

```bash
git clone --recurse-submodules git@github.com:openfoodfacts/openfoodfacts-infrastructure.git
# or, for a clone made before this existed
make -C . install_submodules
```

`make install` then installs the collections Wazuh requires
(`ansible.windows` and `community.windows`, needed for Windows agents even
though we only run Linux ones).

Dependabot keeps the submodule up to date with the `gitsubmodule` ecosystem in
`.github/dependabot.yml`.

### Two consequences of importing

`playbook_dir` is taken from the **top-level** playbook and `import_playbook`
does not change it. The Wazuh roles read their version from
`{{ playbook_dir }}/VERSION.json`, so running from `ansible/` would look for
`ansible/VERSION.json`. We therefore commit that path as a **symlink** to the
vendored file, which tracks the pinned version and never needs updating by
hand.

Wazuh likewise derives `wazuh_credentials_path` and `local_configs_path` from
`playbook_dir`, so its generated credentials and certificates land under
`ansible/` rather than inside the submodule. That is deliberate: it keeps them
out of vendored code, and lets `.gitignore` handle them like normal repository
content.

## Passwords

Wazuh generates five passwords on first run. We supply our own through
`wazuh_credentials_overrides` so that they live in this repository, encrypted:

| Key | Used by |
| - | - |
| `WAZUH_INDEXER_ADMIN_PASSWORD` | indexer API, admin user |
| `WAZUH_INDEXER_KIBANASERVER_PASSWORD` | indexer, dashboard |
| `WAZUH_INDEXER_MANAGER_PASSWORD` | indexer, manager |
| `WAZUH_MANAGER_API_PASSWORD` | manager API |
| `WAZUH_MANAGER_WUI_PASSWORD` | manager web UI |

They belong in `ansible/group_vars/wazuh_cluster/wazuh-secrets.yml`, which is
matched by the `*-secrets.yml` git-crypt rule in `.gitattributes`.

Wazuh enforces a password policy on supplied values: 12 to 64 characters, drawn
from `A-Za-z0-9.,_+:@%^=~-`, with at least one uppercase letter, one lowercase
letter, one digit and one of those symbols. A value that fails is rejected by
**key name only**; the values themselves are never logged.

Supplied passwords are only honoured the first time a deployment is created. To
rotate one later, use `wazuh-passwords-tool.sh` on the container rather than
editing the variable.

## Certificates

The Wazuh internal PKI (indexer, manager and agent certificates) is generated
by the roles themselves, so **no certificates are stored in this repository**.
`generate_certs` is left at its upstream default of `true`.

The upstream playbook downloads `wazuh-certs-tool.sh` and generates a
deployment CA on the control node. Two things follow:

* The CA private key never leaves the control node. It lives in
  `/var/lib/wazuh-ansible/<hash>/ca`, outside any repository, and **must be
  backed up separately**. Losing it means issuing a CA that no existing
  component trusts, with no recovery path.
* Adding a node later is done by deleting
  `ansible/deployment-config-files/wazuh-certificates/` and re-running, which
  issues new certificates from the *same* CA. Never delete the CA directory
  itself.

These are separate from the dashboard's TLS certificate, which for now is the
self-signed one the CA issues, and which is not trusted by browsers.

## Accessing the dashboard

The dashboard is not exposed publicly. For the proof of concept we reach it over
an SSH tunnel:

```bash
ssh -J <your-account>@ovh1.openfoodfacts.org \
    -L 8443:127.0.0.1:443 config-op@10.1.0.160
```

Then open <https://localhost:8443> and accept the certificate warning.

Agents connect to the manager on ports 1514/1515 and the indexer API on 9200.
Traffic is carried over the existing private stunnel network between data
centres (being replaced by WireGuard), so no additional firewall rules are
needed for the proof of concept: those addresses fall inside `10.0.0.0/8`,
which `group_vars/all/common.yml` already whitelists in the `iptables` role.

## Growing beyond a single node

`wazuh-aio.yml` hardcodes `single_node: true`, so moving to a real distributed
deployment is a migration rather than a configuration change:

1. Point `ansible/wazuh.yml` at upstream's `wazuh-distributed.yml`.
2. Declare the nodes in `instances` and add the matching inventory groups
   (`wi_cluster`, `manager`, `worker`, `dashboard`).
3. Delete `ansible/deployment-config-files/wazuh-certificates/` and re-run, so
   certificates are reissued from the same CA.
4. Re-check the indexer heap, which upstream divides by 2 instead of 4 once the
   node is no longer all-in-one.

Existing alerts are preserved, since this upgrades the packages rather than
reinstalling them.

One decision should be made **before** adding a second indexer, not after. Wazuh
indexes are created with a single replica. A second indexer then adds capacity
but no high availability: there is still only one copy of every shard, on one
node. Raising `number_of_replicas` to 1 is easy while the data is small and
expensive once it is not, because existing indices must be reindexed.

## Backups

Snapshots are taken by sanoid on `ovh2` and replicated to `ovh3` by Proxmox ZFS
replication, which is configured outside this repository. From `ovh3` the
snapshots are pushed to `hetzner-01` and `osm45` with syncoid.

Those syncoid configurations enumerate datasets explicitly, and the highest one
currently listed is `subvol-150`. Whether CT 160 is covered end to end therefore
depends on the Proxmox replication job carrying all of `rpool`, which is worth
confirming in the Proxmox interface.

## Known gaps

* The proof of concept is not backed up end to end; see [Backups](#backups).
* The deployment CA has no automated backup; see [Certificates](#certificates).
* The container was created by hand and is not declared in any
  `proxmox_containers__containers` list, so Ansible will not re-create it if it
  is destroyed. `ovh2` is a `non_ansible_hosts` entry, which is why
  `sites/proxmox-node.yml` skips it.
