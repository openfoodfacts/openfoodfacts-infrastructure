# 2012-06-08 Stalled ZFS Sync for off products on ovh3

There were mail (for about one week) from crontab to root,
telling `sto-products-sync.sh` failed with `cannot receive incremental stream: dataset is busy`.

Looking at it on ovh3, I saw that sync was stalled since `2023-05-30 23:30`
(last available snapshot, when issuing `zfs list -t snap rpool/off/products`)

There was also some bytes written to `rpool/off/products`:
```bash
# zfs  get -H written rpool/off/products 
rpool/off/products	written	783K	-
```
Normally this should not be a problem since `sto-products-sync.sh` uses `zfs recv ... -F` which force update by eventually rolling back to last snapshot.
That said I issued a `zfs rollback rpool/off/products@20230530-2330` to see if it would help, it didn't.
I also killed a stalled `zfs recv` process (launched 7h before).

But I then so that on off1, as may snapshot where already cleaned up by retention policy, the `2023-05-30 23:30` snapshot didn't exists any more… Our cleanup policy is a bit too naïve and remove everything from the previous month.
I have to change this, still in a naïve mode, to have two monthes.
It's not a big deal to keep a lot of snapshot as our products data is really incremental (we only add files).

The also a bit long because it have to come back to the `20230501-0000` snapshot,
`sto-products-sync.sh` should still have succeeded, but failed instead. 
This is because `rpool/off/clones/products` is a clone based upon a snapshot from may, thus the rpool/off/products volume can't be rolledback to `20230501-0000` which is an earlier snapshot...


## repairing sync

### Base clone on an older snapshot

I did (temporarily) change the clone products to be based on `20230501-0000` snapshot.

We first have to stop staging (off.net) has it uses clones through NFS.
I verified there were no [deployment action](https://github.com/openfoodfacts/openfoodfacts-server/actions/workflows/container-deploy.yml) in progress.
On docker staging: `cd /home/off/off-net; sudo -u off docker-compose stop`

On ovh3:
```bash
zfs destroy rpool/off/clone/products
zfs clone rpool/off/products@20230501-0000 rpool/off/clones/products
```

Restart staging, on docker-staging: `cd /home/off/off-net; sudo -u off docker-compose start`


### Relaunch sync manually

To better follow what's happening I decided to manually rollback to the common snapshot: `20230501-0000`

on ovh3:
```bash
zfs rollback -r rpool/off/products@20230501-0000
```
I didn't measure but it took something between 20 and 40 minutes.

on off1:
```bash
zfs send -i rpool/off/products@20230501-0000 rpool/off/products@20230608-1130 | ssh ovh3.openfoodfacts.org zfs recv rpool/off/products -F
```

## Change retention policy in scripts

I minimally changed the retention policy part of `sto-products-sync.sh` to avoid removing snapshots too early (2 month ago instead of last month).

`snapshot-purge.sh` used on ovh3 and off2 is working differently and it's already fine, so I didn't changed it.