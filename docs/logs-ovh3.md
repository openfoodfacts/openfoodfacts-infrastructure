# ovh3 server logs

Report here the timeline of incidents and interventions on ovh3 server.
Keep things short or write a report.

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

