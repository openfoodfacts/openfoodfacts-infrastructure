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

**IMPORTANT:** this was not an optimal choice, we should have reserved part of the SSD to use it as a cache drive for the ZFS pool.

Once the install is complete, OVH sends the credentials by email.

We add users for the admin(s) and give sudo access:
```bash
sudo usermod -aG sudo [username]
```

Set hostname `hostnamectl hostname ks1`

I also manually runned the usual commands found in ct_postinstall.

I also followed [How to have server config in git](../how-to-have-server-config-in-git.md)

I also added the email on failure systemd unit.

I edited `/etc/netplan/50-cloud-init.yaml` to add default search
```yaml
network:
    version: 2
    ethernets:
        eno3:
            (...)
            nameservers:
                search: [openfoodfacts.org]
```
and run `netplan try`.

## Email

Email is important to send alert on service failure.

I also configured email by removing exim4 and installing postfix.
```bash
sudo apt purge exim4-base exim4-config && \
sudo apt install postfix bsd-mailx
```
and following [Server, postfix configuration](../mail.md#postfix-configuration).

I also had to had ks1 ip address to [forwarding rules on ovh1 to the mail gateway](../mail.md#redirects).
```bash
iptables -t nat -A PREROUTING -s 217.182.132.133 -d pmg.openfoodfacts.org -p tcp  --dport 25 -j DNAT --to 10.1.0.102:25
iptables-save > /etc/iptables/rules.v4.new
# control
diff /etc/iptables/rules.v4{,.new}
mv /etc/iptables/rules.v4{.new,}
etckeeper commit "added rule for ks1 email"
```

Test from ks1:
```bash
echo "test message from ks1" |mailx -s "test root ks1" -r alex@openfoodfacts.org root
```

## Install and setup ZFS

### Install ZFS
```bash
sudo apt install  zfsutils-linux
sudo /sbin/modprobe zfs
```

Added the `zfs.conf`  file to `/etc/modprobe.d`
Then run `update-initramfs -u -k all`

### Create ZFS pool

`lsblk` shows me existing disks. The 4 disks are available, system is installed on the NVME SSD.

So I created the pool with them (see [How to create a zpool](../zfs-overview.md#how-to-create-a-zpool))

```bash
zpool create zfs-hdd /dev/sd{a,b,c,d}
```

### Setup compression

We want to enable compression on the pool.

```bash
zfs set compression=on zfs-hdd
```

Note: in reality it was not enabled from start, I enabled it after first snapshot sync,
as I saw is was taking much more space than on the original server.

### Fine tune zfs

Set `atime=off` et `relatime=no` on the ZFS dataset `zfs-hdd/off/images` to avoid writting.

## Install sanoid / syncoid

I installed the sanoid.deb that I got from the off1 server.

```bash
apt install libcapture-tiny-perl libconfig-inifiles-perl
apt install lzop mbuffer pv
dpkg -i /home/alex/sanoid_2.2.0_all.deb
```

## Sync data

After installing sanoid, I am ready to sync data.

I first create a off dataset to have same structure as on other servers:
```bash
zfs create zfs-hdd/off
```

I 'll sync the data from OVH3 since it's the same data-center.

I created a ks1operator user on ovh3, following [creating operator on PROD_SERVER](../sanoid.md#creating-operator-on-prod_server)

I also had to make a `ln -s /usr/sbin/zfs /usr/bin/zfs` on ovh3

Then I used:

```bash
 time syncoid --no-sync-snap --no-privilege-elevation ks1operator@ovh3.openfoodfacts.org:rpool/off/images zfs-hdd/off/images
```

It took 3594 minutes, that is 60 hours or 2.5 days.

I removed old snapshots (old style) from ks1, as they are not needed here):
```bash
for f in $(zfs list -t snap -o name zfs-hdd/off/images|grep "images@202");do zfs destroy $f;done
```
the other snapshot will normally be pruned by sanoid.

## Configure sanoid

I created the sanoid and syncoid configuration.

I added ks1operator on off2.

Finally I also installed the standard sanoid / syncoid systemd units and the sanoid_check unit.

and enable them:

```bash
systemctl enable --now sanoid.timer
systemctl enable syncoid.service
systemctl enable --now sanoid_check.timer


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

Addendum: after Christian installed Munin node, I added port 4949

## NGINX

### Install

I installed nginx and certbot:
```bash
apt install nginx
apt install python3-certbot python3-certbot-nginx
```

I also added the nginx.service.d override to email on failure.

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
```

## Testing

On my host I modified /etc/hosts to have:
```hosts
217.182.132.133 images.openfoodfacts.org
```
and visited the website with my browser, with developer tools open.

I can also use curl:
```bash
curl --resolve images.openfoodfacts.org:443:217.182.132.133 https://images.openfoodfacts.org/images/products/087/366/800/2989/front_fr.3.400.jpg  --output /tmp/front_fr.jpg -v
xdg-open /tmp/front_fr.jpg
```
