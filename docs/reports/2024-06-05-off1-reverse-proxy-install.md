# 2024-06 OFF1 reverse proxy install + OFF images container

A new IP address has been allocated so that we can install a nginx reverse proxy on off1.
The reverse proxy will directly serve static OFF product images.

I (Stéphane) will follow what was done by Alex for the reverse proxy on off2: 2023-03-14-off2-opff-reinstall.md 


## NGINX reverse proxy install

### Installing Container

I followed [How to create a new Container](../proxmox.md#how-to-create-a-new-container)

I chose 4 cpu, 2 Gb RAM, 32 Gb disk (same as proxy on off2)

CT number is 100

debian-12-standard_12.2-1
Network: name=eth0,bridge=vmbr1,ip=10.1.0.100/24,gw=10.0.0.1

### Install nginx

I then simply install `nginx` using apt.

I also [configure postfix](../mail#postfix-configuration) and tested it.

### Adding the IP

Using proxmox interface, on container 100, I add net1, on vmbr0, IP 213.36.253.215/27, Gateway 213.36.253.222 (copied from Host config).

I reboot the container 100, and it seems to work, I can access the nginx using the IP address.

### declaring DNS entry

I added an A record `off1-proxy.openfoodfacts.org` to point to this IP in OVH DNS zones.

### Cloning git infra repository

I created a ssh key as root:
```bash
ssh-keygen -t ed25519 -C "off@off1-proxy.openfoodfacts.org"
cat /root/.ssh/id_ed25519.pub
```
and add it as [authorized key in openfoodfacts-infrastructure](https://github.com/openfoodfacts/openfoodfacts-infrastructure/settings/keys) with write authorization (as it will be mainly modified directly in the container).


Then I cloned the repository in /opt
```
cd /opt
git clone git@github.com:openfoodfacts/openfoodfacts-infrastructure.git
```

### Re-enforcing security thanks to fail2ban

Install fail2ban.

We reuse the existing `confs/proxy-off/fail2ban/jail.d/nginx` using debian provided feature for nginx
Then:
```bash
sudo ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/fail2ban/jail.d/nginx.conf /etc/fail2ban/jail.d/
systemctl reload fail2ban
```

**NOTE**: it's really not enough, but to analyze 403 / 401 we need a specific plugin that analyze logs.

### Mounting volumes

We will serve images directly from the reverse proxy (in order to not require to have a separate "images" container that serves images). The reason is to avoid having an extra nginx layer (with logs etc.) for image files that are requested very often.

I edit /etc/pve/lxc/100.conf

and add:

mp0: /zfs-hdd/off/images,mp=/mnt/off/images
mp1: /zfs-hdd/obf/images,mp=/mnt/obf/images
mp3: /zfs-hdd/opff/images,mp=/mnt/opff/images

TODO: For some reason /zfs-hdd/opf does not exist on the off1 host.


### SSL certificates

I copy the letsencrypt certificates and configurations from off2 host to the off1 reverse proxy.

Then I install letsencrypt in the off1 reverse proxy container.

sudo apt install certbot python3-certbot-nginx
(fixed: at first I forgot the nginx plugin)

#### Testing SSL renewals

sudo certbot renew --dry-run

Failed to renew certificate images.openfoodfacts.org with error: The requested nginx plugin does not appear to be installed

Installed python3-certbot-nginx

2nd try:

Detail: 213.36.253.208: Fetching http://images.openfoodfacts.org/.well-known/acme-challenge/GUG0men38f_steRovK_AmCPyaV4lCyJUA3N8teSWp3I: Connection refused

TODO: check if this is because the live images.openfoodfacts.org currently points to off2.


### NGINX configuration

We reuse the existing `log_format.conf` file with log format definition:
```conf
log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                  '$status $body_bytes_sent "$http_referer" '
                  '"$http_user_agent" "$http_x_forwarded_for"';
```
It's in the git repository, so then:

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/log_format.conf /etc/nginx/conf.d/log_format.conf
```

From off2 static-off configuration, I create a similar images-off site, and put it into git.

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/off1-reverse-proxy/nginx/sites-available/images-off /etc/nginx/sites-enabled/
```

Changes from static-off:
- I put log files in /var/log/nginx instead of a zfs mount
- Path to images are to /mnt/off instead of /zfs-hdd/off as we are in a container and not the host
- Removed the upstream directive which was not used
- Fixed paths to SSL certificates (copied from off2 host)


### Testing

To test, I change my local /etc/hosts file to add:
213.36.253.215 images.openfoodfacts.org

The upstream times out:

2024/06/04 13:25:25 [error] 1666#1666: *1 upstream timed out (110: Connection timed out) while connecting to upstream, client: 91.175.166.38, server: images.openfoodfacts.org, request: "GET /images/products/560/247/784/2456/front_fr.3.200.jpg HTTP/2.0", upstream: "https://213.36.253.214:443/images/products/560/247/784/2456/front_fr.3.200.jpg", host: "images.openfoodfacts.org", referrer: "https://fr.openfoodfacts.org/"

We can't access proxy2.openfoodfacts.org from inside the container (why?)

Changing:

proxy_pass              https://proxy2.openfoodfacts.org;

To use directly the IP of the off container:

proxy_pass              http://10.1.0.113:80;

Which works.


### TODO

- Also do the setup for OBF, OPF, OPFF: nginx configuration, SSL certificates etc.
- Check why we don't have /zfs-hdd/opf on off1
- Verify that off1 can renew the images.openfoodfacts.org SSL certificate
- Export proxy logs and static logs to prometheus?