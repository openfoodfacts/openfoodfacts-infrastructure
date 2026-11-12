# 2026-11-12 slow images on scaleway-03

Since images.openfoodfacts.org was moved to scaleway-03
(see [2026-09-23 temporarily moving images to scaleway-03](./2026-09-23-temporarily-moving-images-to-scaleway-03.md)),
images are sometimes very slow to load.

## Symptoms

Fetching the same image 5 times from outside:

```
200 total=5.858012s ttfb=5.824322s
200 total=0.284476s ttfb=0.282474s
200 total=1.110455s ttfb=1.108534s
200 total=5.250311s ttfb=5.248261s
200 total=0.694830s ttfb=0.692855s
```

The file was surely in the ZFS ARC after the first request,
so the time is spent waiting before the request is handled, not reading this file.

Note: testing with curl from scaleway-03 itself does not work,
because the DNAT to CT 116 is only in `PREROUTING` (incoming traffic).

## Investigation

`$request_time` over the last 100k requests of `/var/log/nginx/images-access.log` in CT 116:

```
proxy n=4012  p50=0.203 p90=3.284 p99=6.489 max=60.207
local n=95988 p50=0.000 p90=0.253 p99=9.895
```

(`local` = served from disk, `proxy` = fetched from world.openfoodfacts.org)

Traffic is around 7500 requests / minute.

`zpool iostat -l zfs-hdd 5` shows ~500-650 read IOPS (~100 per disk),
with a read `disk_wait` of 15-18ms, which is normal for HDDs, and almost no queueing.
That is around 4-5 disk reads per request.

The nginx workers (6, as the CT has 6 cores and `worker_processes auto`)
were in `D` state (`cv_timedwait_common`, waiting on ZFS) nearly all the time:

```bash
for i in $(seq 10); do pct exec 116 -- ps -o pid,stat,wchan:25,cmd -C nginx | grep worker; echo ---; sleep 1; done
```

An nginx worker is single threaded: while it waits on a disk read (open, stat, read)
all its other connections wait, including the ones for files that are in cache.
With only 6 workers and ~125 req/s, each needing a few 15ms disk reads,
the workers can't keep up and requests wait for seconds.

## Fix

* added `confs/scaleway-images-tmp/nginx/nginx.conf` (it was not in git)
  with `worker_processes 32` and a smaller `thread_pool`
* added `aio threads` in the `location /` of `images.openfoodfacts.org`,
  so file reads are done in a thread pool instead of in the worker

`aio threads` does not cover `open()`/`stat()` (directory and metadata lookups),
which is why we also raise the number of workers.

This does not increase what the disks can do (~600 random read IOPS),
but requests for cached files no longer wait behind slow disk reads.
The real fix is still to move images to a server with faster storage (scaleway-05).

### Deploying

`/etc/nginx/nginx.conf` already exists in the CT as a regular file,
so the ansible symlink task would refuse to run. We first move it aside:

```bash
# in CT 116
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
```

then:

```bash
ansible-playbook sites/reverse-proxy.yml -l scaleway-images-tmp --tags git-config,nginx
```
