# 2026-10-10 OVH2 160 (wazuh) POC Setup

Given the large variety and amount of servers and containers in the OpenFoodFacts
infrastructure, it's becoming more and more difficult to know which system is
in which state and might require maintenance. We set up a proof of concept
instance of [Wazuh 5.0 RC1](https://wazuh.com/) on OVH2, and added some agents
on LXC containers to present sample data from our infrastructure.

Create new CT 160 with Debian 11 (newest available template)

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

Then, I followed the [ansible docs](ansible/docs/index.md#prepare-a-new-host-server) to add the `config-op` user with a random password.

```bash
root@wazuh:/# GITHUB_USER_NAME=hangy
root@wazuh:/# useradd -m -s /bin/bash -G sudo config-op
root@wazuh:/# passwd config-op
root@wazuh:/# runuser -u config-op -- mkdir /home/config-op/.ssh
root@wazuh:/# runuser -u config-op -- wget -O /home/config-op/.ssh/authorized_keys https://github.com/$GITHUB_USER_NAME.keys
```