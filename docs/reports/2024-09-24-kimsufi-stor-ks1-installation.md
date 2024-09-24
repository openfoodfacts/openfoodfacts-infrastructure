# Kimsufi STOR - ks1 installation

## Rationale for new server

We have performance issues on off1 and off2 that are becoming unbearable, in particular disk usage on off2 is so high that 60% of processes are in iowait state.

We just moved today (24/09/2024) images serving from off2 to off1, but that just move the problem to off1.

We are thus installing a new cheap Kimsufi server to see if we can move the serving of images to it.

## Server specs

KS-STOR - Intel Xeon-D 1521 - 4 c / 8 t - 16 Gb RAM - 4x 6 Tb HDD + 500 Gb SSD

## Install

We create a A record ks1.openfoodfacts.org to point it to the IP of the server: 217.182.132.133
In OVH's console, we rename the server to ks1.openfoodfacts.org

On OVH console, we install Debian 12 Bookworm on the SSD.

Once the install is complete, OVH sends the credentials by email.

We add users for the admin(s) and give sudo access:
```bash
sudo usermod -aG sudo [username]
```

Set hostname `hostnamectl hostname ks1`

I also manually runned the usual commands found in ct_postinstall.

I also followed [How to have server config in git](../how-to-have-server-config-in-git.md)


## Install and setup ZFS

### Install ZFS
```bash
sudo apt install  zfsutils-linux
sudo /sbin/modprobe zfs
```

Added the `zfs.conf`  file to `/etc/modprobe.d`

### Create ZFS pool

`lsblk` shows me existing disks. The 4 disks are available, system is installed on the NVME SSD.

So I created the pool with them (see [How to create a zpool](../zfs-overview.md#how-to-create-a-zpool))

```bash
zpool create zfs-hdd /dev/sd{a,b,c,d}
```

## Install sanoid / syncoid

I installed the sanoid.deb that I got from the off1 server.

```bash
apt install libcapture-tiny-perl libconfig-inifiles-perl
apt install lzop mbuffer pv
dpkg -i /home/alex/sanoid_2.2.0_all.deb
```


## Sync data

After installing sanoid, I am ready to sync data.

I sync them from OVH3 since it's the same data-center.

I createed a ks1operator user on ovh3, following [creating operator on PROD_SERVER](../sanoid.md#creating-operator-on-prod_server)

I also had to make a `ln -s /usr/sbin/zfs /usr/bin/zfs` on ovh3

Then I used:

```bash
 time syncoid --no-sync-snap --no-privilege-elevation ks1operator@ovh3.openfoodfacts.org:rpoo/off/images zfs-hdd/off-images
```

## Configure sanoid

**FIXME** todo

## Firewall

As the setting will be simple (no masquerading / forwarding), we will use ufw.

```bash
apt install ufw

ufw allow OpenSSH
ufw allow http
ufw allow https
ufw default deny incoming
ufw default allow outgoing

# verify
ufw show added
# go
ufw enable
```

fail2ban is already installed, but failing with:
```
Failed during configuration: Have not found any log file for sshd jail
```
This is because the sshd daemon logs into systemd-journald, not in a log file.
To fix that, I modified `/etc/fail2ban/jail.d/defaults-debian.conf` to be:
```ini
[sshd]
enabled = true
backend = systemd
```


## NGINX

### Install

I installed nginx and certbot:
```bash
apt install nginx
apt install python3-certbot python3-certbot-nginx
```

### Configure

Created `confs/ks1/nginx/sites-available/images-off` akin to off1 configuration.

`ln -s /opt/openfoodfacts-infrastructure/confs/ks1/nginx/sites-available/images-off /etc/nginx/sites-enabled/images-off`

### Certificates

As I can't use certbot until having the DNS pointing to this server,
I copied the one from off1.

```bash
ssh -A off1
sudo -E bash
# see active certificates
ls -l /etc/letsencrypt/live/images.openfoodfacts.org/
# here it's 19, copy them
scp /etc/letsencrypt/archive/images.openfoodfacts.org/*19* alex@ks1.openfoodfacts.org:

exit
exit
```

On ks1:
```bash
mkdir -p /etc/letsencrypt/{live,archive}/images.openfoodfacts.org
mv /home/alex/*19* /etc/letsencrypt/archive/images.openfoodfacts.org/
ln -s /etc/letsencrypt/archive/images.openfoodfacts.org/cert19.pem /etc/letsencrypt/live/images.openfoodfacts.org/cert.pem
ln -s /etc/letsencrypt/archive/images.openfoodfacts.org/chain19.pem /etc/letsencrypt/live/images.openfoodfacts.org/chain.pem
ln -s /etc/letsencrypt/archive/images.openfoodfacts.org/fullchain19.pem /etc/letsencrypt/live/images.openfoodfacts.org/fullchain.pem
ln -s /etc/letsencrypt/archive/images.openfoodfacts.org/privkey19.pem /etc/letsencrypt/live/images.openfoodfacts.org/privkey.pem
chown -R root:root /etc/letsencrypt/
chmod go-rwx /etc/letsencrypt/{live,archive}