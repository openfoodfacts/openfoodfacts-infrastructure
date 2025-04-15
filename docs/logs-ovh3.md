# ovh3 server logs

Report here the timeline of incidents and interventions on ovh3 server.
Keep things short or write a report.

## 2024-10-31 system taking 100% CPU

* Server is not accessible via SSH. 
* Munin show 100% CPU taken by system.
* We ask for a hard reboot on OVH console.
* After restart system continues to use 100% CPU.
* Top shows that arc_prune + arc_evict are using 100% CPU
* exploring logs does not show strange messages
* `cat /proc/spl/kstat/zfs/arcstats|grep arc_meta` shows a arc_meta_used < arc_meta_max (so it's ok)
* We soft reboot the server
* It is back to normal

## 2024-10-10

sda on ovh3 is faulty (64 Current_Pending_Sector, 2 Reallocated_Event_Count).
See https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/424



## 2023-12-05 certificates for images expired

Images not displaying anymore on the website due to SSL problem (signaled by Edouard, with alert by blackbox exporter)
In syslog:
```log
Dec  5 13:12:58 off2 certbot[385770]: Failed to renew certificate images.openfoodfacts.org with error: The requested nginx plugin does not appear to be installed
```
Checked `/etc/letsencrypt/renewal/images.openfoodfacts.org.conf` it uses nginx authenticator.
To resolve:
```bash
apt install python3-certbot-nginx
certbot renew
```
also `mv /etc/letsencrypt/renewal/ovh3.openfoodfacts.org.{conf,backup}` as the domain is not served anymore

## 2023-09-12 logrotate nginx

Nginx has a big static-access.log file (52G).
I changed `/etc/logrotate.d/nginx` to take into account `/rpool/logs-nginx/*.log` and launched `/usr/sbin/logrotate /etc/logrotate.conf`.

## 2023-09-07 ZFS dataset stalled

The day before, we switch back images.openfoodfacts.org to ovh3.
Alert was images.openfoodfacts.org down.
Trying to restart nginx, it failed and left behind zombie processes, that can't be killed even with `kill -9` (meaning there a stuck waiting an I/O).
I could list a file (`ls /rpool/off/images/products/376/002/924/8001/1.100.jpg`)
but getting content wait indefinitely (`cat /rpool/off/images/products/376/002/924/8001/1.json`).
zpool status takes a lot of time to run and indicates 1 READ error on sdb.
We did a hard reboot.
see [Slack thread](https://openfoodfacts.slack.com/archives/C01F18SQ8F7/p1694089024775499).

##  2023-07-16 Disk sdc errors on OVH3

See [ 2023-07-16 Disk sdc errors on OVH3](./reports/2023-07-16-ovh3-sdc-broken.md)

## 2023-06-08 ZFS dataset stalled

Nginx images not responding, as well as off.net.

ZFS dataset stop to work at 00:50 (UTC) in the morning.
Add to do a hard reboot - no symptoms in log.
[slack thread](https://openfoodfacts.slack.com/archives/C1FPYCWM7/p1686298752505019)


## 2023-05-30 ZFS dataset stalled

Hard reboot.

## 2023-05-04 ZFS dataset stalled

Hard reboot.

