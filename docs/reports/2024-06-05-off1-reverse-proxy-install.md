# 2024-06 OFF1 reverse proxy install + OFF images container

**⚠️ IMPORTANT:** We finally didn't use this reverse proxy which was intended to serve images due to un-explained performance issues.
We didn't have the time to investigate more.

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

I also [configure postfix](../mail.md#postfix-configuration) and tested it.

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
mp2: /zfs-hdd/opf/images,mp=/mnt/opf/images
mp3: /zfs-hdd/opff/images,mp=/mnt/opff/images

Initially /zfs-hdd/opf did not exist on the off1 host, because of a typo in /etc/sanoid/syncoid-args.conf on off1.
Fixed the config and ran a first sync manually:
syncoid --no-sync-snap --no-privilege-elevation --recursive off1operator@10.0.0.2:zfs-hdd/opf zfs-hdd/opf

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

We reuse the existing `nginx.conf`:

```bash
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.old
ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/nginx.conf /etc/nginx/
```

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

From off2 static-off configuration, I create a similar images-off site, and put it into git (in `confs/off1-reverse-proxy/nginx/sites-available/images-off`).

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

# Services setup

We copy the services structure we have on off2 in the proxy 101 container:

root@proxy:/etc/systemd/system# ls -lrt | grep opt
lrwxrwxrwx 1 root root  91 Sep  8  2023 fail2ban.service.d -> /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/systemd/fail2ban.service.d
lrwxrwxrwx 1 root root  89 Nov 20  2023 nginx.service.d -> /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/nginx.service.d
lrwxrwxrwx 1 root root  93 Nov 20  2023 logrotate.service.d -> /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/logrotate.service.d
lrwxrwxrwx 1 root root  97 Nov 21  2023 email-failures@.service -> /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/email-failures@.service
lrwxrwxrwx 1 root root  93 Jan  5 18:51 stunnel@.service.d -> /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/stunnel@.service.d/
lrwxrwxrwx 1 root root  91 Jan 19 13:18 certbot.service.d -> /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/certbot.service.d
lrwxrwxrwx 1 root root 109 May 27 14:26 prometheus-nginx-exporter.service.d -> /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/prometheus-nginx-exporter.service.d

ln -s /opt/openfoodfacts-infrastructure/confs/common/fail2ban-nftables/systemd/fail2ban.service.d /etc/systemd/system
ln -s /opt/openfoodfacts-infrastructure/confs/off1-reverse-proxy/systemd/system/prometheus-nginx-exporter.service.d /etc/systemd/system/
ln -s /opt/openfoodfacts-infrastructure/confs/off1-reverse-proxy/systemd/system/logrotate.service.d /etc/systemd/system/
ln -s /opt/openfoodfacts-infrastructure/confs/off1-reverse-proxy/systemd/system/nginx.service.d /etc/systemd/system/
ln -s /opt/openfoodfacts-infrastructure/confs/off1-reverse-proxy/systemd/system/certbot.service.d /etc/systemd/system/


# Nginx exporter on off2 proxy and off

## On off2 reverse proxy


### Expose nginx stats

For nginx exporter we need to expose /stub_status on port 8080 (see [doc](https://github.com/nginxinc/nginx-prometheus-exporter)) https://nginx.org/en/docs/http/ngx_http_stub_status_module.html#stub_status

I created the `stub_status` conf for that (linked from this repository). I limited to 127.0.0.1, it should be internal.

Test it: `curl http://127.0.0.1:8080`

### Install Prometheus nginx exporter

In container 100, install the exporter:
`sudo apt install prometheus-nginx-exporter`

As we are on a public interface, we don't want to expose the exporter widely, so we restrict it to 10.1.0.100 so that we can query it from the proxy container on off2.

For that we edit /opt/openfoodfacts-infrastructure/confs/off1-reverse-proxy/systemd/system/prometheus-nginx-exporter.service.d/override.conf to change the IP:

```conf
[Service]
# ONLY listen on 10.1.0.100 for security reasons
# We do not put 127.0.0.1 as we want to access the prometheus export from the proxy container on off2.
Environment="LISTEN_ADDRESS=10.1.0.100:9113"
```
And moved it to versioned space:
```bash
mv /etc/systemd/system/prometheus-nginx-exporter.service.d /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/ && \
ln -s /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/prometheus-nginx-exporter.service.d /etc/systemd/system/
```

Reload: `systemctl daemon-reload && systemctl restart prometheus-nginx-exporter`

Check exporter status: `systemctl status prometheus-nginx-exporter`

Test it from the proxy container on off2:
```bash
curl http://10.1.0.100:9113/metrics
```

Test it's not available from the public interface:
```bash
nc -vz 213.36.253.215 9113
nc: connect to 213.36.253.215 port 9113 (tcp) failed: Connection refused
```

### Expose the metrics

Edit the `/etc/nginx/sites-enabled/free-exporters.openfoodfacts.org`
to add the right entry to the map directive:

```conf
# map from service to exporter
map $uri $exporter {
    ...
    # nginx on this proxy
    "/proxy/nginx/metrics" 127.0.0.1:9113;
    ...
```

Restart nginx and test it:
```
curl -u prometheus:**password-here**  https://free-exporters.openfoodfacts.org/proxy/nginx/metrics
```


## Add the exporter to the monitoring stack

Edit `prometheus/config.yml` to add the service path to free-exporters section.
(see [commit 845759a](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/845759a68528b60bcc47e9b5860bc72940431032))

The nginx dashboards works immediately.

### TODO

- Also do the setup for OBF, OPF, OPFF: nginx configuration, SSL certificates etc.
- Verify that off1 can renew the images.openfoodfacts.org SSL certificate
- Export proxy logs and static logs to prometheus?

## 2024/06/06 - Performance issues

We are seeing performance issues with serving images on the off1 proxy in container 100.
Some images can take 10 seconds to be served back by nginx, and it can clearly be seen when loading lists of products on the website.

Private message thread: https://openfoodfacts.slack.com/archives/C074EACK8TH/p1717687142646649

### Trying to serve images directly from the off1 host instead of a container

We suspect that the slowness is due to the bind mount of the zfs pool with images.
So we will try to serve images directly from the off1 host instead of the 100 container (like we currently do on off2)

apt-get install nginx

ln -s /opt/openfoodfacts-infrastructure/confs/off1/nginx/sites-available/images-off /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default 
rm /etc/nginx/nginx.conf 
ln -s /opt/openfoodfacts-infrastructure/confs/proxy-off/nginx/nginx.conf /etc/nginx/
cp -a /zfs-hdd/pve/subvol-100-disk-0/etc/letsencrypt /etc/

TODO: properly install letsencrypt if it works and we want to keep serving images on the host.


**⚠️ IMPORTANT:** We finally abandonned using off1 to server images, due to un-explained performance issues.
We didn't have the time to investigate more.