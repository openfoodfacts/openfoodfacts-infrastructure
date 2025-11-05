# Note sur l'installation des serveurs Open Food Facts chez Hetzner

Le serveur est livré en mode "rescue".

Depuis ce mode on peut lancer un script d'installation avec la commande:

`installimage`

Doc Hetzner: https://docs.hetzner.com/robot/dedicated-server/operating-systems/installimage/

Après une analyse de la machine, elle prépare un fichier de configuration de l'installation qu'on peut modifier selon ses besoins.

Les changements à faire portent sur:
- les disques où installer l'OS
- le type de RAID à installer
- leur partitionnement
- le hostname

## Config "installimage" pour un serveur de stockage

Les serveurs de stockage ont 4 HDD SATA et 2 SSD NVMe.

Ces serveurs ne semblent pas pouvoir booter sur les disques NVMe.

L'OS (debian 12/bookworm) sera donc installé sur les HDD, en RAID1 (mirroir) et en ext3/4 en réservant 256Go pour / car le reste sera alloué au pool ZFS. On installera ensuite promox par dessus.

Donc on modifie le fichier de config pour avoir :

```
DRIVE1 /dev/sda
DRIVE2 /dev/sdb
DRIVE3 /dev/sdc
DRIVE4 /dev/sdd

SWRAID 1
SWRAIDLEVEL 1

HOSTNAME h1.openfoodfacts.org
```

Le partitionnement par défaut doit aussi être modifié pour que la partition / n'occupe pas tout le disque mais 256G.

Le reste est inchangé.

On peut ensuite lancer l'installation, qui est très rapide !

## Installation de Proxmox

Voir: https://pve.proxmox.com/wiki/Install_Proxmox_VE_on_Debian_12_Bookworm

Rien de particulier donc:

```
echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list
wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg 
apt update && apt full-upgrade -y
apt install proxmox-default-kernel -y
reboot
```

Après le redémarrage du serveur:

```
apt install proxmox-ve postfix open-iscsi chrony -y
apt remove linux-image-amd64 'linux-image-6.1*' -y
update-grub
apt remove os-prober -y
```

## Désactivation portmapper (BSI)

```
systemctl stop rpcbind rpcbind.socket
systemctl disable rpcbind rpcbind.socket
```

([Source](https://www.bsi.bund.de/EN/Themen/Unternehmen-und-Organisationen/Cyber-Sicherheitslage/Reaktion/CERT-Bund/CERT-Bund-Reports/HowTo/Offene-Portmapper-Dienste/Offene-Portmapper-Dienste_node.html))

## Pool ZFS sur les serveurs de stockage

Création des partitions sur l'espace restant des HDD:

```
apt install parted -y

parted /dev/sda mkpart zfs hdd-zfs 280G 100%
parted /dev/sdb mkpart zfs hdd-zfs 280G 100%
parted /dev/sdc mkpart zfs hdd-zfs 280G 100%
parted /dev/sdd mkpart zfs hdd-zfs 280G 100%
```

Création du pool ZFS:

```
zpool create hdd-zfs -o ashift=12 raidz1 sda5 sdb5 sdc5 sdd5 cache nvme0n1 nvme1n1
zpool export hdd-zfs
zpool import hdd-zfs -d /dev/disk/by-id/
zfs set compress=on xattr=sa atime=off relatime=on hdd-zfs
```

That's all folks !