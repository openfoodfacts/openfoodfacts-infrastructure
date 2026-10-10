# 2026-10-10 OVH2 160 (wazuh) POC Setup

Given the large variety and amount of servers and containers in the OpenFoodFacts
infrastructure, it's becoming more and more difficult to know which system is
in which state and might require maintenance. We set up a proof of concept
instance of [Wazuh 5.0 RC1](https://wazuh.com/) on OVH2, and added some agents
on LXC containers to present sample data from our infrastructure.

## Create new CT 160 with Debian 11 (newest available template)

```bash
hangy@ovh2:~$ sudo pct create 160 local:vztmpl/debian-11-standard_11.3-0_amd64.tar.gz --arch amd64 --cores 4 --hostname wazuh --memory 8192 --net0 name=eth0,bridge=vmbr0,gw=10.0.0.1,ip=10.1.0.160/24,type=veth --rootfs zfs:50 --unprivileged 1
```

Start and enter the container

```bash
hangy@ovh2:~$ sudo pct start 160
hangy@ovh2:~$ sudo pct enter 160
```

Need to upgrade Debian to a supported version first.

```bash
root@wazuh:/# mv /etc/apt/sources.list /etc/apt/sources.list.bak
root@wazuh:~# cat > /etc/apt/sources.list.d/debian.sources <<EOF
Types: deb
URIs: https://debian.mirrors.ovh.net/debian
Suites: bookworm bookworm-updates
Components: main non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://debian.mirrors.ovh.net/debian-security
Suites: bookworm-security
Components: main non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
root@wazuh:~# wget http://ftp.de.debian.org/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2023.3+deb12u2_all.deb
root@wazuh:~# dpkg -i debian-archive-keyring_2023.3+deb12u2_all.deb
root@wazuh:~# rm debian-archive-keyring_2023.3+deb12u2_all.deb
root@wazuh:~# apt update
root@wazuh:~# apt -y full-upgrade
```

For this upgrade of an empty server, I just said "Yes" to every question asked, and rebooted the LXC afterwards. Then, I
removed old packages.

```bash
hangy@ovh2:~$ sudo pct reboot 160
hangy@ovh2:~$ sudo pct enter 160
root@wazuh:/# apt -y autoremove
```

Manually ran some commands adapted from [`ct_postinstall`](https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/e27503a8b4ded38d9e2cbc103b7d8f6bfe8c6cb3/scripts/proxmox-management/ct_postinstall).

```bash
root@wazuh:/# apt install -y sudo curl etckeeper htop fail2ban molly-guard lsb-release vim bsd-mailx tree screen munin-node
root@wazuh:/# echo 'alias ll="ls -al"' >> /etc/bash.bashrc
root@wazuh:/# echo 'export TERM=xterm-256color' >> /etc/bash.bashrc
root@wazuh:/# cp /etc/skel/.bashrc /root/
root@wazuh:/# sed -i 's/\(%sudo.*\)ALL$/\1NOPASSWD:ALL/' /etc/sudoers
```

Then, I followed the [ansible docs](../ansible/index.md#prepare-a-new-host-server) to add the `config-op` user with a random password.

```bash
root@wazuh:/# GITHUB_USER_NAME=hangy
root@wazuh:/# useradd -m -s /bin/bash -G sudo config-op
root@wazuh:/# passwd config-op
root@wazuh:/# runuser -u config-op -- mkdir /home/config-op/.ssh
root@wazuh:/# runuser -u config-op -- wget -O /home/config-op/.ssh/authorized_keys https://github.com/$GITHUB_USER_NAME.keys
```

## Ansible

The Wazuh ansible setup was described in [services](../explanation/services/wazuh.md). When running, the playbook,
the `wazuh-indexer` didn't start because OpenSearch requires privileges that are not available on unprivileged containers.

The service failed with:

```bash
wazuh-indexer.service: Failed to set up mount namespacing: /run/systemd/unit-root/proc: Permission denied
Failed at step NAMESPACE spawning /usr/share/wazuh-indexer/bin/systemd-entrypoint: Permission denied
Main process exited, code=exited, status=226/NAMESPACE
```

OpenSearch's systemd unit relies on systemd sandboxing (`ProtectSystem`, `PrivateTmp`, ...), which makes systemd
build a per-unit mount namespace. The LXC AppArmor profile blocks the mounts systemd needs. `wazuh-dashboard` is
also OpenSearch and needs the same, so the setting applies to the whole container.

Converting the container in place is not possible:

```bash
hangy@ovh2:~$ sudo pct set 160 --unprivileged 0
unable to modify read-only option: 'unprivileged'
```

`unprivileged` can only be set at creation time. I first recreated the container as **privileged**, on the
assumption that OpenSearch needed root. That was wrong: the error persisted, because it is not a privilege
problem. See below.

## The container needs `features: nesting=1`, and must stay unprivileged

This is a long-standing [AppArmor bug](https://wiki.debian.org/LXC/SystemdMountsAndAppArmor)
(lp:1597017), not a privilege problem. `lxc/lxc#4052` reports the same failure in *both* privileged and
unprivileged containers. The LXC AppArmor profile restricts the mount flags systemd needs in order to build
a per-unit mount namespace, so the unit exits `226/NAMESPACE`.

The fix is `--features nesting=1`, which makes LXC use the `lxc-container-default-with-nesting` AppArmor
profile:

```bash
hangy@ovh2:~$ sudo pct destroy 160
hangy@ovh2:~$ sudo pct create 160 local:vztmpl/debian-11-standard_11.3-0_amd64.tar.gz --arch amd64 --cores 4 --hostname wazuh --memory 8192 --net0 name=eth0,bridge=vmbr0,gw=10.0.0.1,ip=10.1.0.160/24,type=veth --rootfs zfs:50 --unprivileged 1 --features nesting=1
hangy@ovh2:~$ sudo pct start 160
```

!!! warning "Do not combine privileged with nesting"

    Debian's guidance is that nesting is acceptable for **unprivileged** containers but *risky for privileged
    ones*: the nesting AppArmor profile effectively permits any mount because of the very parser bug that
    causes this failure. A privileged container therefore gets the worst of both worlds, with none of the
    isolation benefit and still not working.

Do not try to convert with a backup either: restoring a backup taken from an unprivileged container into a
privileged one does not remap ownership, and everything, including `/etc/passwd` and apt's database, would show
up as `nobody`.

Recreating is cheap here. The Ansible playbook is idempotent, and the deployment CA lives on the control node in
`/var/lib/wazuh-ansible/<hash>/ca` rather than in the container, so a re-run re-stages certificates from the same
CA instead of issuing a new one.

So we ran the same steps from the first chapter again.
