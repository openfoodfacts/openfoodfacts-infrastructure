# 2026-10-10 migrating off1 and off2 to scaleway-04 and 05

We migrated the two Free datacenter DELL servers (off1, off2) to the Scaleway
bay: renamed them scaleway-04 and scaleway-05, upgraded PVE 7 → 9, moved their
guests along (renumbered VMIDs), and joined them to the pvescaleway cluster
(scaleway-01 to 03). ZFS cross-backups with the cluster are configured.

## Preparing the data

- Backed up CT123 from sc5 (off2) to sc3, using a manual syncoid command.
- Set up the new network config: new public IPs (151.115.132.14/15 — see
  [free-datacenter.md](../reference/free-datacenter.md)) and DNS servers.
- Created the `scaleway03operator` on sc4 and sc5, so that sc3 can pull from
  them:
  ```
  ansible-playbook sites/proxmox-node.yml \
      --limit scaleway-03 \
      --tags sanoid
  ```

## PVE 7 → 8 (on both nodes)

- Check: `pve7to8 --full`
- Update Debian sources:
  ```
  sudo sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list
  sudo sed -i -e 's/bullseye/bookworm/g' /etc/apt/sources.list.d/pve-install-repo.list
  ```
- Fix a typo in `/etc/modprobe.d/zfs.conf`: it must be `options`, not `option`
- As the two nodes are not connected, run with an expected quorum of one:
  `sudo pvecm expected 1`
- `sudo apt update && sudo apt dist-upgrade`
- Reboot

## PVE 8 → 9 (on both nodes)

- Re-apply the expected quorum after the reboot:
  ```
  sudo pvecm expected 1
  sudo systemctl start pvescheduler.service
  ```
- Check: `sudo pve8to9 --full`
- Update Debian sources:
  ```
  sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list
  sudo sed -i 's/bookworm/trixie/g' /etc/apt/sources.list.d/pve-install-repo.list
  ```
- `sudo apt update && sudo apt dist-upgrade`
- Reboot
- Deactivate the enterprise repo:
  `echo "Enabled: no" | sudo tee -a /etc/apt/sources.list.d/pve-enterprise.sources`

## Renaming the nodes

- `sudo nano /etc/hostname` — off1 → scaleway-04, off2 → scaleway-05
- `sudo nano /etc/hosts` — same base as sc1

## Leaving the old cluster (on sc4 and sc5)

```
# 1. Stop cluster services
sudo systemctl stop pve-cluster corosync

# 2. Start cluster filesystem in local mode
sudo pmxcfs -l

# 3. Remove Corosync configs
sudo rm -f /etc/pve/corosync.conf /etc/corosync/corosync.conf

# 4. Restart pmxcfs in standard mode
sudo killall pmxcfs
sudo systemctl start pve-cluster
```

Reboot.

## Moving the guests to the new node names

On **sc4** (from off1):

```
sudo mkdir -p /etc/pve/nodes/scaleway-04/qemu-server /etc/pve/nodes/scaleway-04/lxc
sudo mv /etc/pve/nodes/off1/qemu-server/* /etc/pve/nodes/scaleway-04/qemu-server/ 2>/dev/null
sudo mv /etc/pve/nodes/off1/lxc/* /etc/pve/nodes/scaleway-04/lxc/ 2>/dev/null
sudo rm -rf /etc/pve/nodes/off1 /etc/pve/nodes/off2

# regenerate SSL certificates for the new node name
sudo pvecm updatecert -f
sudo systemctl restart pveproxy
```

On **sc5** (from off2): same with `scaleway-05` / `off2`.

The migrated guests' VMIDs were renumbered to values unused in the
pvescaleway cluster (renaming their config files in
`/etc/pve/nodes/<node>/{qemu-server,lxc}`), so that the guest configs could
merge into the cluster pmxcfs without VMID conflicts.

## Repository configuration (branch `tsvg/feat-add-sc4-sc5`)

- Inventory: sc4/sc5 replace off1/off2 (public IPs, `proxmox_api_local_port`,
  `extra_host_ips`), in the `pvescaleway` group; `host_vars` and secrets created.
- Sanoid cross-backups: syncoid jobs moved from `confs/off1`, `confs/off2` to
  `confs/scaleway-04`, `confs/scaleway-05` (the sanoid role links configs by
  `ansible_hostname`); operators `scaleway04operator` (on sc5) and
  `scaleway05operator` (on sc4) declared in new `host_vars/*/sanoid.yml`;
  sc1-03 operator lists extended to pull from sc4/sc5; dead `confs/off1`,
  `confs/off2` removed.

Then applied:

```
ansible-playbook jobs/configure.yml --limit scaleway-04,scaleway-05
ansible-playbook sites/proxmox-node.yml --limit pvescaleway
```

## Issues found and fixed on the way

Several runs were needed; the blockers below are fixed in the branch:

- **`aisbergg.zfs` crashes under ansible-core 2.19+** (new templating engine):
  the `selectattr2` filter fails on missing dict keys — blocked all runs on
  scaleway-01. Fixed with explicit `scrub`/`trim` keys in `host_vars` for
  scaleway-01, hetzner-01, hetzner-02 (`roles.galaxy/` is not tracked).
- **`zfs-dkms` from trixie-backports breaks dpkg**: PVE kernels bundle their
  own (newer) ZFS modules, so the backport's postinst fails whenever a new
  kernel lands (unattended-upgrades installed 7.0.14 on sc1/sc3, leaving all
  apt broken). Purged `zfs-dkms` on all pvescaleway nodes and removed it from
  the role's Debian package loop (local `roles.galaxy` patch; fork patch +
  `requirements.yml` bump pending).
- **sc3 stuck dpkg**: same cause plus an undocumented nvidia stack (driver
  615.71 cannot build for kernel 7.0.14). Purged the staged kernel and held
  it (`apt-mark hold proxmox-kernel-7.0.14-23-pve-signed`) until the driver is
  upgraded; restored `/etc/zfs/zpool.cache` lost in the churn.
- **Debian netinst ISO pin**: pinned 13.1.0 against the rolling `/current/`
  cdimage path broke at every point release — switched to the versioned 13.7.0
  path (like pvehetzner).
- **`virtiofs`**: a `when` evaluating to a list (not a boolean) crashed the
  acltype check on sc2/sc3 under ansible-core 2.19+ — made boolean.
- **`git_based_configs`**: fresh clones landed on the repository default branch
  and immediately required an interactive branch switch (broken in
  multi-host runs) — clones now start directly at the target branch.
- **`proxmox_containers`**: the `pveam available | grep -o ...` captured the
  whole line (version/arch columns) into the template filename — now extracts
  the first column with awk.
- **The cluster join itself silently failed**: `pvecm add` refuses a node
  containing guest configs ("Check if node may join a cluster failed!") — which
  sc4/sc5 deliberately had — and **PVE 9's CLI exits 0 on that failure**, so
  every run reported success without joining. Joining manually, with the
  guests parked outside pmxcfs:
  ```
  sudo mkdir -p /root/join-backup/{qemu-server,lxc}
  sudo mv /etc/pve/nodes/scaleway-04/qemu-server/*.conf /root/join-backup/qemu-server/
  sudo mv /etc/pve/nodes/scaleway-04/lxc/*.conf /root/join-backup/lxc/
  sudo rm /etc/corosync/authkey     # leftover from the old cluster
  sudo pvecm add 10.13.0.3 --use_ssh --link0 10.13.0.4 --link1 scaleway-04
  sudo mv /root/join-backup/qemu-server/*.conf /etc/pve/nodes/scaleway-04/qemu-server/
  sudo mv /root/join-backup/lxc/*.conf /etc/pve/nodes/scaleway-04/lxc/
  ```
  (same on sc5 with `scaleway-05`, `10.13.0.5`)
- **IPv6**: host config (`2001:bc8:c025:10::4/48` / `::5/48`, gateway
  `...:ff7f`, /48 like sc1) validated on sc4, but the shared bay router drops
  all traffic from unknown global sources (`::1`-`::3` work, every fresh test
  address is ignored). Removed the config meanwhile; needs registering with
  whoever operates the bay router (Fondation Free / OSM France side — the /48
  is a Scaleway range but Scaleway's support is not the party).

## Result

- 5-node `pvescaleway` cluster, quorate; sc4/sc5 visible in the web UI with
  their guests.
- ZFS cross-backups sc4 ↔ sc5 (sanoid + syncoid), operators created on each
  other, sanoid/syncoid timers active; `zpool.cache` restored on all nodes.

## Follow-ups

- corosync link1 on sc4/sc5 points to 127.0.0.1 (at join time, `--link1
  <hostname>` resolved to the `/etc/hosts` localhost entry), so the new nodes run
  on link0 only while sc1-03 carry a link1. Either set link1 to their public IPs
  (edit `/etc/pve/corosync.conf`, then `corosync-cfgtool -R`), or make link
  addressing consistent cluster-wide.
- IPv6 on sc4/sc5: register `2001:bc8:c025:10::4/5` with the bay router, then
  re-apply the host config and add AAAA records.
- iptables role: ipsets are never persisted for boot (`/etc/ipset.conf` is
  never written) — hosts boot firewall-less until the next rules change, and
  re-running the playbook does not restore them (restores are gated on template
  change). Run `sudo netfilter-persistent save` per host after verifying the
  live rules, and fix the role (persist ipsets + un-gate the restores).
- Patch the `alexgarel/ansible-role-zfs` fork (make the Debian package list
  overridable) and bump the version in `ansible/requirements.yml`, so the
  local `zfs-dkms` loop patch survives role reinstalls.
- sc3: upgrade the nvidia driver to a kernel-7.0-capable branch (find out what
  the orphaned CUDA 13-3 stack is for first), then
  `apt-mark unhold proxmox-kernel-7.0.14-23-pve-signed`.
- sc1 emits Router Advertisements on the bay segment (appears as `router` in
  neighbors' NDP tables; nothing in the repo installs radvd) — investigate.
- Report upstream: `pvecm add` exits 0 on join refusal (PVE 9); the lae role's
  cluster detection silently skips nodes that self-report a cluster and its
  `_pve_found_clusters` intersection starts empty.
