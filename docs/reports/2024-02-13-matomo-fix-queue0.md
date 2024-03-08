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