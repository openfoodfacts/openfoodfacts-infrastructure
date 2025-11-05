# 2025-10-22 Hetzner Proxmox 8 to 9

Proxmox 9 is out and this is the one installed on Scaleway servers.

I want to migrate hetzner cluster from Proxmox 8 to proxmox 9, so that:
* it's identical to scaleway
* I can rerun the proxmox install playbook to verify it's still working.

## Doing it

### Upgrading servers

I follow https://pve.proxmox.com/wiki/Upgrade_from_8_to_9

I log to each server hetzner-01/2/3 and run:
```bash
apt update
apt dist-upgrade
pveversion
```

Now one by one, starting with hetzner-03 which has nothing running:
```bash
pve8to9
```
On hetzner-03 it tells me:
```
WARN: storage 'hdd-zfs-pve' enabled but not active!
...
WARN: systemd-timesyncd is not the best choice for time-keeping on servers, due to only applying updates on boot.
  While not necessary for the upgrade it's recommended to use one of:
    * chrony (Default in new Proxmox VE installations)
    * ntpsec
    * openntpd
...
WARN: dkms modules found, this might cause issues during upgrade.
...
TOTAL:    46
PASSED:   39
SKIPPED:  4
WARNINGS: 3
FAILURES: 0
```
It's ok for me

On hetzner-02 it also tells me:
```
...
WARN: 4 running guest(s) detected - consider migrating or stopping them.
...
WARN: VM 999 - volume 'local:999/vm-999-cloudinit.qcow2' (in config) - storage does not have content type 'images' configured.
WARN: Proxmox VE enforces stricter content type checks since 7.0. The guests above might not work until the storage configuration is fixed.
...
TOTAL:    47
PASSED:   37
SKIPPED:  4
WARNINGS: 6
FAILURES: 0
```
Still ok

```bash
sed -i 's/bookworm/trixie/g' /etc/apt/sources.list /etc/apt/sources.list.d/*.list
apt update
apt dist-upgrade
```

* I ask to not save ip sets and iptables rules.
* I got a conflict on /etc/issue but keep mine
* I ask to not restart services linked to libc6 (as I will reboot) but say ok for minimal restart (ssh cron atd)
* I got a conflicts:
  * I kept my version on
    * /etc/systemd/timesyncd.conf
    * /etc/zfs/zed.d/zed-functions.sh
  * I accept changes for
    * /usr/share/unattended-upgrades/20auto-upgrades (ansible run will configure it)
    * /usr/share/unattended-upgrades/50unattended-upgrades (ansible run will configure it) 
    * /etc/fail2ban/jail.d/defaults-debian.conf
    * /etc/lvm/lvm.conf (as proposed by documentation)
    * /etc/default/grub (comments only)
    * /etc/ssh/ssh_config (changes will be redone by the ansible playbook)

I rerun the check:
```bash
pve8to9
```

Then I reboot:
```bash
reboot
```

I had to disable pve-enterprise which was added by default.
(I saw that when runnig the ansible playbooks):

```bash
sed -i 's/^/# /' /etc/apt/sources.list.d/pve-enterprise.sources
```

### Running ansible playbooks

Using ansible:
```bash
ansible-playbook jobs/configure.yml -l hetzner-01,hetzner-02,hetzner-03
ansible-playbook sites/proxmox-node.yml -l hetzner-01,hetzner-02,hetzner-03
```

**Note:** I had to run `ansible-galaxy install -r requirements.yml  --force` to have correct version of lae.proxmox


## Some improvements

I had to fix different things to have the script completely running:

* hetzner-02 and -03 did not yet had a sanoid configuration
* running ansible.builtin.pause in parallel does not seems to work well,
  so I added a `git_based_configs__branch_switch_confirmation` variable
  to `git_based_configs` role
  that can be set with `--extra-vars`
* I had to change the pvehetzner group and cluster name so that it matches
* I had to change proxmox_node__iso because debian versions have changed
  (a pity latest version can't be found in archive…)
* I realize we where not syncinc volumes from hetzner-02/03 to hetzner-01
  with sanoid, so I added it
* I stumble on a problem with create_container.yml
  as ansible specify fully the python version by default,
  so pct connection was not working
  because it was searching a non existing version of python
  inside the container (python3.13) where debian version is older.
  I fixed it by adding `ansible_python_interpreter: "/usr/bin/python3"` in vars.
