# 2014-02-13 Matomo fix Queue0

Following up [2024-01 Matomo performance tunning](./2024-01-matomo-perf-tunning.md)
the queue 0 is not catching up it's work and after decreasing, is growing again at a steady pace.

So I propose to:
* stop queue 0 timer/service
* rename the list in redis
* start queue 0 timer/service
* start a specific process in a screen to consume the renamed list

```bash
# stop queue 0 timer / service
systemctl stop matomo-tracking@0.timer matomo-tracking@0.service
sytemctl status matomo-tracking@0.service

# rename the list in redis
redis-cli
> keys *
1) "trackingQueueV1_1"
2) "trackingQueueV1"
3) "trackingQueueV1_2"
4) "fooList"
5) "trackingQueueV1_3"
> rename trackingQueueV1 trackingQueueV1_4
OK
> del QueuedTrackingLock0
> quit

# re-enable queue 0 timer / service
systemctl start matomo-tracking@0.timer

# start a screen
screen -S matomo-queue

# start a process to consume the renamed list, starting again on errors
while true; do /var/www/html/matomo/console queuedtracking:process --queue-id=4 -v -n;/var/www/html/matomo/console queuedtracking:lock-status --unlock=QueuedTrackingLock4 -n --ignore-warn; sleep 60; done
```

Monitoring progress

Using:
```bash
while true; do data=$(redis-cli </home/alex/redis-cmp.txt|tr "
" ";"); echo $(date +"%Y-%m-%d-%H-%M")";"$data |tee -a matomo-queues.csv ; sleep 600 ; done
2024-03-11-09-32;87121;120871;45993;112289;59;145;48;83;586841;
```
where `/home/alex/redis-cmp.txt` is

```bash
llen trackingQueueV1
llen trackingQueueV1_1
llen trackingQueueV1_2
llen trackingQueueV1_3
llen trackingQueueV1_4
llen trackingQueueV1_5
llen trackingQueueV1_6
llen trackingQueueV1_7
llen trackingQueueV1_8
```


| Date/Time | queue 0 | queue 1 | queue 2 | queue 3 | queue 4 |
|--|--|--|--|--|--|
| 02-13 11:56| 1674 | 485 | 958 | 598 | 616998 |
| 02-13 12:04| 2480 | 31 | 512 | 64 | 615998 |
| 02-13 12:20 | 3130 | 872 | 603 | 92   | 615998 |
| 02-13 14:28 | 8445 | 800 | 592 | 682 | 604998 |
| 02-13 14:28 | 8445 | 800 | 592 | 682 | 604998 |
| 02-13 14:28 | 8445 | 800 | 592 | 682 | 604998 |
| **crash at some point ** | | | | | |
| 02-13 18:47 | 17717 | 106  | 937 | 892 | 596998 |


At some point the php process dies with a:
```
  [PDOException]
  SQLSTATE[HY000]: General error: 2006 MySQL server has gone away
```
I had to relaunch it.


To verify it's working, I also installed strace, 
look for the pid of my queue0 process: `ps -elf|grep queue-id`, 
and then use `strace -p 12740 2>&1|grep INSERT`.

`strace -p 12258 2>&1|grep INSERT|pv -lri60 >/dev/null` gives the number of insert per seconds


## Doing it again

I did understand what maybe causing the problem of queue 0 being too big.

See [Queue id should try to be more random #231](https://github.com/matomo-org/plugin-QueuedTracking/issues/231) and [Set a random visitor ID at each requests instead of using 0000000… for anonymous analytics](https://github.com/openfoodfacts/smooth-app/issues/5095)

In between, I decide to add a temporary queue 4 again to cope.

## Patching matomo code

As I can't wait deployment of mobile app fix, I decided to patch the matomo code to
avoid visitor_id 00000000 and instead use a random visitor id with a random first letter in this case.

I edit plugins/QueuedTracking/Queue/Manager.php:

```php
    protected function getQueueIdForVisitor($visitorId)
    {
        # 2024-03-08 patch from ALEX
        if ($visitorId === '0000000000000000') {
            $visitorId = chr(rand(ord('a'), ord('z')));
        }
        $visitorId = strtolower(substr($visitorId, 0, 1));
```

and restart matomo:
`systemctl restart php7.3-fpm.service`

## Adding more workers

After some times, I saw that all queues are going up now… after the week-end they have between 45000 and 125000 items late !


So I decided to change the number of workers to 8:
* I first moved my queue 4 that I used for coping with old entries to be queue 16 (strangely queue 17 does not work…).
* going in matomo, change tracking queues configuration to 8
* create and start corresponding timers:
  * `systemctl enable matomo-tracking@{4,5,6,7}.timer`
  * `systemctl start matomo-tracking@{4,5,6,7}.timer`


## Avoid lock lost

Maybe because mariadb is a bit slow on the server, there are a lot of lock lost, leading each time to the matomo tracking service to fail…
eg:
```
Rolled back during processing as we no longer have lock or the lock was never acquired. So far tracker processed 0 requests
```

I decided to patch the code once again… in `plugins/QueuedTracking/Queue/Processor.php`:

```php
    private function extendLockExpireToMakeSureWeCanProcessARequestSet(RequestSet $requestSet)
    {
        // 2 seconds per tracking request should give it enough time to process it
        // 2024-03-15 ALEX try 15 s per requests instead of 2s
        $ttl = $requestSet->getNumberOfRequests() * 150;
        $ttl = max($ttl, 30); // lock for at least 30 seconds

        return $this->queueManager->expireLock($ttl);
    }
```

## Perf tunning on mariadb

Since it was under control, but queues were still a bit high (around 3500 items per queue) I launched `mysqltuner` 
and followed some of its proposals to tune mariadb.

See [commit 0018356592f2](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/0018356592f23ee494ea7d0581d012a1ea95fcdf)