# 2023-12-11 Matomo down

Matomo is not responding on 2023-12-11 morning.
We either got "gateway timeout" or "An error occured"

The incident went unnoticed, which shows that Matomo is not monitored.


## Resolution

### Monitoring matomo

I added blackbox monitoring for matomo, following https://matomo.org/faq/how-to/faq_20278/

* monitoring https://analytics.openfoodfacts.org/index.php?module=Login for admin access
* https://analytics.openfoodfacts.org/matomo.php for trackers access

see [openfoodfacts-monitoring commit:db8f911ce](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/db8f911ce48de278752232229b63b85e780e1a4a)


### Restarting fpm-php

A `systemctl restart php7.3-fpm.service` do put the service back online but for a short time only… after some minutes it's unresponsive again.

### Looking at processes

`ps -elf|grep php` shows us that all php thread seems occupied at doing `"archive:core"` it correspond to the task launched by `/etc/cron.d/matomo-archive`.

This is something really needed to get statistics, matomo rely on that.


### Adding more child processes to fpm-php

I edit `/etc/php/7.3/fpm/pool.d/www.conf` to add more child processes:  (`pm.max_children` scaled up from 5 to `30`).

This does not resolve the problem. The bottleneck seems to be the database !

All fpm-php processes are stucked polling while lot of processes are still doing archive:core

### Zombies

At some point I realize that may php processes are indeed zombies ! (parent pid is 1).

So I decide to reboot the container.

I also decided to avoid archive:core running multiple time in parallel.
So I modified `/etc/cron.d/matomo-archive` to be:
```
MAILTO="root@openfoodfacts.org"
# only start if no process is already running
5 * * * * www-data ps -elf|grep "core:archive" || /usr/bin/php /var/www/html/matomo/console core:archive --url=http://analytics.openfoodfacts.org/ >> /var/log/matomo/matomo-archive.log 2>>/var/log/matomo/matomo-archive-err.log
```

### Configured infrastructure git on the matomo container

One good way of keeping track of specific work done in an install is to track files the infrastructure git repository.

To clone the openfoodfacts-infrastructure project on matomo container:

#. I generated a key `ssh-keygen -t ed25519 -C "root+analytics@openfoodfacts.org"`
#. I added the public key top openfoodfacts-infrastructure as a deploy key
#. cloned it in /opt/openfoodfacts-infrastructure (as on other servers)

### Configure with git

After moving the files to the repository,
```bash
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/mysql/mariadb.conf.d/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/cron.d/matomo-archive /etc/cron.d/matomo-archive
```

I also added systemd email on failure for various services.

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/systemd/email-failures@.service /etc/systemd/system
systemctl daemon-reload
# test
systemctl start email-failures@test-alex-analytics.service
```


### Re-configure email

Email was not well configured, did see that by doing a `systemctl start email-failures@test-alex-analytics.service` to test it.

* `apt install bsd-mailx`
* `dpkg-reconfigure postfix` following instructions on [how to setup email](../mail.md#postfix-configuration)


### Optimize Matomo for performances

Going to [parameters, system, general parameter, archival parameters](https://analytics.openfoodfacts.org/index.php?module=CoreAdminHome&action=generalSettings&idSite=1&period=day&date=yesterday&activated=&mode=admin&type=&show=#), I verified that Matomo is configured that we do not archive reports from the browser, and that we only do it once an hour.

(see https://matomo.org/faq/on-premise/how-to-set-up-auto-archiving-of-your-reports/)

But finally after I observed untrack failures (process hung so cron not relaunching…), I decided to use systemd timer + service.

```bash
unlink  /etc/cron.d/matomo-archive
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/systemd/matomo-archive.* /etc/systemd/system
systemctl daemon-reload
systemctl enable matomo-archive.timer
systemctl start  matomo-archive.timer
```

### Optimize MariaDB performances

Added some RAM and CPUs

https://vitux.com/tune-and-optimize-mysql-mariadb/
https://mariadb.com/kb/en/configuring-mariadb-for-optimal-performance/

Relevant files are in this repository and linked in `/etc`

### Using Redis

I first installed redis and phpredis on the server:
`sudo apt install redis php-redis`
with a restart of php ``

Following https://matomo.org/faq/on-premise/how-to-configure-matomo-to-handle-unexpected-peak-in-traffic/

- Got QueuedTracking in the [Platform / market place in our Matomo instance](https://analytics.openfoodfacts.org/index.php?module=Marketplace&action=overview&idSite=1&period=day&date=yesterday&activated=&mode=admin&type=&show=)
- Activate the QueuedTracking plugin in “Matomo Administration > Plugins “
- Under “Matomo Administration > System > General Settings > QueuedTracking”
- Select Backend = Redis, Select Number of Queue workers = 1
- Select Number of requests that are processed in one batch = 100
- Disable the setting Process during tracking request

Then I setup a cronjob that executes the command ./console queuedtracking:process every minute:

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/cron.d/matomo-tracking /etc/cron.d/matomo-tracking
```

But finally after I observed untrack failures (process hung so cron not relaunching…), I decided to use systemd timer + service.


```bash
unlink  /etc/cron.d/matomo-tracking
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/systemd/matomo-tracking.* /etc/systemd/system
systemctl daemon-reload
systemctl enable matomo-tracking.timer
systemctl start  matomo-tracking.timer
```


### Install Prometheus nginx exporter

While at it, it may help.

`sudo apt install prometheus-nginx-exporter`

For nginx exporter we need to expose /stub_status on port 8080 (see [doc](https://github.com/nginxinc/nginx-prometheus-exporter)) https://nginx.org/en/docs/http/ngx_http_stub_status_module.html#stub_status

I created the `stub_status` conf for that (linked from this repository).

Check status: `systemctl status prometheus-nginx-exporter`

Test it locally:
```bash
curl http://127.0.0.1:9113/metrics
curl http://10.1.0.107:9113/
```

Tested it from ovh2, it does not work but from ovh1 it works !


### Install Prometheus mysqld exporter

`sudo apt install prometheus-mysqld-exporter`

I then had to edit `default/prometheus-mysqld-exporter` (linked from this repository) to add:
```conf
DATA_SOURCE_NAME="prometheus:nopassword@unix(/run/mysqld/mysqld.sock)/"
```

And create the user in the database using `mysql` command:
```sql
CREATE USER IF NOT EXISTS 'prometheus'@'localhost' IDENTIFIED VIA unix_socket;
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'prometheus'@'localhost';
```

Then restart the service:
```bash
systemctl start prometheus-mysqld-exporter
```

Testing:

```bash
systemctl status prometheus-mysqld-exporter
curl "http://127.0.0.1:9104/metrics"
curl "http://10.1.0.107:9104/metrics"
```

### Install Prometheus redis exporter

It's not present in current distribution so I didn't install it !

### Monitoring

Now to be able to monitor those, I added them to monitoring configuration.