# 2026-11-08 Moji docker VM killed by OOM

## Symptoms

On 2026-11-09, some facet pages on Open Food Facts were slow and showed "no products",
e.g. https://world.openfoodfacts.org/facets/teams/sciensano-belgium-2026-thomasmore-n004

The `data_debug` HTML comment at the end of the page showed:

```
count tags using off_query
count_documents using MongoDB
```

In `estimate_result_count()` (ProductOpener `Display.pm`),
the MongoDB fallback is only used when off-query returns no value at all (a count of 0 would not trigger it),
so every call to off-query was failing,
and ProductOpener was falling back to MongoDB everywhere.

From the off container, off-query (through the stunnel client on `10.13.1.101:16001`) was not answering:

```bash
curl -s -X POST 'http://10.13.1.101:16001/count' -H 'Content-Type: application/json' \
  -d '{"teams_tags":"sciensano-belgium-2026-thomasmore-n004"}' -w '\nHTTP %{http_code} in %{time_total}s\n'
# HTTP 000 in 2.514440s
```

`HTTP 000` means stunnel accepted the connection, then closed it because it could not reach the backend.
https://query.openfoodfacts.org/health was returning `502 Bad Gateway`.

## Investigation

The chain is:
off (scaleway) → stunnel client `10.13.1.101:16001` → moji stunnel server (osm45) `:::16001`
→ `10.3.0.200:5511` (off-query in VM 200 `docker-prod-2` on osm45).

`ssh prod2docker` (jump through osm45) failed with "No route to host".
On osm45:

```
root@osm45:~# qm status 200
status: stopped
```

The host journal shows the cause:

```
Nov 08 00:50:21 osm45 kernel: nfsd invoked oom-killer: gfp_mask=0x100cc0(GFP_USER), order=0, oom_score_adj=0
Nov 08 00:50:28 osm45 kernel: oom-kill:constraint=CONSTRAINT_NONE,...,global_oom,task_memcg=/qemu.slice/200.scope,task=kvm,pid=464320,uid=0
Nov 08 00:50:28 osm45 kernel: Out of memory: Killed process 464320 (kvm) total-vm:111437580kB, anon-rss:51612kB, file-rss:2688kB, shmem-rss:104844992kB, ...
Nov 08 00:50:28 osm45 kernel: Out of memory: Killed process 464313 (virtiofsd) total-vm:105260728kB, anon-rss:303568kB, file-rss:4032kB, shmem-rss:88095616kB, ...
Nov 08 00:50:22 osm45 systemd[1]: 200.scope: Failed with result 'oom-kill'.
Nov 08 00:50:50 osm45 qmeventd[807654]: Starting cleanup for 200
```

So the **host** (not the VM) ran out of memory, and the OOM killer killed the kvm process of VM 200.
All services in that VM were down: off-query, Robotoff, off-exports, paddlex.

## Root cause

osm45 has 125 GB of RAM. Its memory budget was:

| Component | Memory |
|---|---|
| VM 200 (`docker-prod-2`) | 100 GB |
| ZFS ARC max (`zfs_arc_max`) | 32 GB |
| L2ARC headers | 3.4 GB |
| **Total** | **≈ 135 GB** |

Since we added virtiofs mounts of podata to VM 200 (July 2026, for openfoodfacts-exports),
the VM's RAM is backed by shared memory (see `shmem-rss` above).
This memory cannot be reclaimed or ballooned by the host,
so the whole 100 GB is effectively pinned once the guest has touched it.

The OOM was triggered by nfsd (the backups NFS share served by osm45) around 00:50,
when the ARC was full and the VM was using its full memory.

## Resolution

On 2026-11-09, on osm45:

```bash
qm start 200
```

All containers came back automatically. `https://query.openfoodfacts.org/health` returned 200 again.

off-query then processed the Redis events backlog:
the last processed event before the restart was at 2026-11-08 00:41 UTC,
and the last generated one at 2026-11-09 09:35 UTC, so about 33h of updates to replay.

To avoid a new OOM, I lowered the ZFS ARC max from 32 GB to 16 GB
(effective right away and kept on reboot):

```bash
echo "options zfs zfs_arc_max=17179869184" > /etc/modprobe.d/zfs.conf
echo 17179869184 > /sys/module/zfs/parameters/zfs_arc_max
update-initramfs -u
```

The new budget is about 100 + 16 + 3.4 GB + host overhead ≈ 122 GB, which is still tight.

## Follow-ups

* Lower VM 200 memory to about 88 GB at the next planned restart:
  `qm set 200 --memory 90112`
* Add an alert on VM 200 status and/or on https://query.openfoodfacts.org/health
  (the outage lasted about 33h before anyone noticed).
* off-query `/health` reports `last_scheduled_update: 2026-10-27T01:59:59Z`:
  the nightly incremental import from MongoDB (02:00) seems to have stopped working
  about 12 days before this incident. This needs to be investigated separately.
