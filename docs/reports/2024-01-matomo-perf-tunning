# 2024-01 Matomo performance tunning

We still have Matomo archive scripts failing…

Trying to optimize it.

**NOTE:** some of the changes documented here are in [commit 32c01fe796a1](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/32c01fe796a119b377d19e8bf14cd81534ce9795)

## using mysqltunner

In a screen as root: `mysqltuner`, it is advized to let it run for 48h

## PHP settings

Edited `/etc/php/7.3/fpm/php.ini` and set as seen on /etc/php/7.3/fpm/php.ini

(I only had to change max_execution_time)
```ini
memory_limit = 2G
max_execution_time = 0
log_errors = On
display_errors=Off
```

For `/etc/php/7.3/cli/php.ini`
```ini
memory_limit = -1
max_execution_time = 0
log_errors = On
display_errors=Off
```

I also add the `path/to/matomo/config/common.config.ini.php` as advised (but with a different log path)

Then `systemctl restart php7.3-fpm.service`

## More MariaDB Optimization

Followed [article on tmpfs for mysql on 2bits.com](https://2bits.com/articles/reduce-your-servers-resource-usage-moving-mysql-temporary-directory-ram-disk.html) (cited by [Matomo docs](https://matomo.org/faq/on-premise/how-to-configure-matomo-for-speed/)) to add:

```conf
tmpdir=/run/mysqld
innodb_flush_log_at_trx_commit=2
```

We could try to set `innodb_flush_method` to `O_DSYNC` but installed mariadb version does not support it.

in `/etc/mysql/mariadb.conf.d/90-off-configs.cnf`

Then `systemctl restart mariadb.service`

Following https://mariadb.com/docs/server/ref/mdb/status-variables/Threads_created/

I run:

```bash
MariaDB [(none)]> SELECT threads_created, connections,     (threads_created / connections) AS thread_cache_miss_rate  FROM     (SELECT gs1.VARIABLE_VALUE AS threads_created     FROM informat
ion_schema.GLOBAL_STATUS gs1     WHERE gs1.VARIABLE_NAME LIKE 'Threads_created') tc JOIN     (SELECT gs2.VARIABLE_VALUE AS connections     FROM information_schema.GLOBAL_STATUS gs2     WHERE
 gs2.VARIABLE_NAME LIKE 'Connections') c;
+-----------------+-------------+------------------------+
| threads_created | connections | thread_cache_miss_rate |
+-----------------+-------------+------------------------+
| 9               | 239         |    0.03765690376569038 |
+-----------------+-------------+------------------------+
1 row in set (0.001 sec)
```

thread_cache_miss_rate is almost 0 which is a good sign.


## Optimize the archiver launch

Changed the exit time for `matomo-archive.service` to `5h`

I use `/usr/bin/php /var/www/html/matomo/console core:archive --help` to see options.

We could use `--force-idsites` to try to launch websites one by one, but I'm not sure it would help, for now (appart from launching archivers in parallel, but it may not help because bottleneck is certainly MariaDB).


## Trying to see what's in redis


Exploring with redis:
```bash
root@analytics:/var/log/matomo# redis-cli
127.0.0.1:6379> select 0
OK
127.0.0.1:6379> keys *
1) "trackingQueueV1"
2) "QueuedTrackingLock0"
3) "fooList"
127.0.0.1:6379> llen trackingQueueV1
(integer) 3886031
127.0.0.1:6379> get QueuedTrackingLock0
"f8e0ba116e18"
(...)
127.0.0.1:6379> get QueuedTrackingLock0
"340aa64aebd3"
127.0.0.1:6379> ttl QueuedTrackingLock0
(integer) 1910
```

So we have a trackingQueueV1 with a lot of tracking records to process. (so it seems we didn't loose anything…)
Also we have a have a lock with a uuid, which changes after some time, and has a quite high ttl.

## Some useful commands

Reading at the [source code](https://github.com/matomo-org/plugin-QueuedTracking),
I also discovered some commands:

There is a lock-status command
```bash
/usr/bin/php /var/www/html/matomo/console queuedtracking:lock-status --help
Usage:
 queuedtracking:lock-status [--unlock="..."]

Options:
 --unlock              If set will unlock the given queue.
 --help (-h)           Display this help message
 --quiet (-q)          Do not output any message
 --verbose (-v|vv|vvv) Increase the verbosity of messages: 1 for normal output, 2 for more verbose output and 3 for debug
 --version (-V)        Display this application version
 --ansi                Force ANSI output
 --no-ansi             Disable ANSI output
 --no-interaction (-n) Do not ask any interactive question
 --matomo-domain       Matomo URL (protocol and domain) eg. "http://matomo.example.org"
 --xhprof              Enable profiling with XHProf
 --ignore-warn         Return 0 exit code even if there are warning logs or error logs detected in the command output.
```

and a monitoring command:
```bash
/usr/bin/php /var/www/html/matomo/console queuedtracking:monitor --help
Usage:
 queuedtracking:monitor [--iterations="..."]

Options:
 --iterations          If set, will limit the number of monitoring iterations done.
 --help (-h)           Display this help message
 --quiet (-q)          Do not output any message
 --verbose (-v|vv|vvv) Increase the verbosity of messages: 1 for normal output, 2 for more verbose output and 3 for debug
 --version (-V)        Display this application version
 --ansi                Force ANSI output
 --no-ansi             Disable ANSI output
 --no-interaction (-n) Do not ask any interactive question
 --matomo-domain       Matomo URL (protocol and domain) eg. "http://matomo.example.org"
 --xhprof              Enable profiling with XHProf
 --ignore-warn         Return 0 exit code even if there are warning logs or error logs detected in the command output.
```

## Trying to launch the service by hand

Stop current and verify it's not running
```bash
systemctl stop matomo-tracking.timer
systemctl status matomo-tracking.service
... dead
```

Start manually in a screen:
```bash
/usr/bin/php /var/www/html/matomo/console queuedtracking:process -v
```

It seems to be processing. To verify let's look at the database.

When we started, in mysql we had:
```SQL
MariaDB [matomo_db]> select count(*) from matomo_log_visit where visit_last_action_time > '2024-01-1
6';
+----------+
| count(*) |
+----------+
|    44581 |
+----------+
``````

1 h after:
```SQL
MariaDB [matomo_db]> select count(*) from matomo_log_visit where visit_last_action_time > '2024-01-16';
+----------+
| count(*) |
+----------+
|    47785 |
+----------+
```

So it's working but it's quite slow (~3000 / h).

## Augmenting the service max execution time

The problem with current service settings is that the TimeoutStartSec is maybe too low.
When a tracking service is stopped, it might leave the lock behind it, with a ttl that might be a bit high, so it then restart a lot of time without doing anything because of the lock.

## Going to 4 tracker queues

Matomo propose to use more than one queue to handle incoming requests. This is what we will do.

Modification of [matomo Queuetracker plugin settings](https://analytics.openfoodfacts.org/index.php?module=CoreAdminHome&action=generalSettings&idSite=1&period=day&date=yesterday&activated=#/QueuedTracking) to have 4 queues.

Modification of matomo-tracking service to run 4 services and queues (using instance name).

```bash
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/systemd/matomo-tracking@.service /etc/systemd/system
ln -s /opt/openfoodfacts-infrastructure/confs/matomo/systemd/matomo-tracking@.timer /etc/systemd/system
systemctl disable matomo-tracking.timer
unlink /etc/systemd/system/matomo-tracking.service
unlink /etc/systemd/system/matomo-tracking.timer
systemctl daemon-reload
systemctl enable matomo-tracking@{0,1,2,3}.timer
systemctl start matomo-tracking@{0,1,2,3}.timer
```

See [commit 640895428](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/640895428351826b22f571327de3df2ee6f6e76c)

We can see it's running:
```bash
systemctl status matomo-tracking@{0..3}.timer
```

In redis we see the different queues that have been created:
```bash
$ redis-cli
127.0.0.1:6379> keys *
1) "QueuedTrackingLock0"
3) "trackingQueueV1_2"
4) "trackingQueueV1"
5) "trackingQueueV1_3"
6) "fooList"
```
