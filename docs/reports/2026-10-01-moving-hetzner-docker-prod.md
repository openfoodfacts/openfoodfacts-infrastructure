# 2026-10-01 moving hetzner-docker-prod

We have 3 servers at hetzner, but really we need only 2 for now.
So I decided to move the only service on hetzner-03 hetzner-docker-prod to hetzner-02

## Preparing migration

To prepare the migration, I added replication of hetzner-docker-prod VM from hetzner-03 to hetzner-02 (I did that using the proxmox web interface)

I also cloned the ZFS corresponding to virtiofs, doing it has root for sake of simplicity:
```
syncoid --recursive root@10.12.0.3:rpool/virtiofs/qm-202 rpool/virtiofs/qm-202
```

I then added the virtiofs resource for hetzner-02 as it was added for hetzner-03 (I did it manually, in *datacenter*, *directory mappings*.)

I shutdown the hetzner-docker-prod VM cleanly and then, resync the virtiofs (using same command as above) and planned a replication of the VM in the proxmox interface.

## Migrating

I then use the "migrate" action in proxmox interface, it went smooth.

On hetzner-02, I then run: 
```bash
qm start 202
```

I need not change hetzner-proxy config of `/etc/nginx/sites-enabled/hetzner-exporters.conf` as we use same ip.
I need not change superset postgres config, as we use same ip.

## Verification

I modified my ssh config to join hetzner-docker-prod to use `ProxyJump hetzner-02` (instead of 03).

I ssh to hetzner-docker-prod and verify the docker are launched correctly.

I used superset to verify that the postgres database work and is answering queries, I can also see that it received latest updates events by running:
```SQL
SELECT
  event.id, event.received_at
FROM product_update_event AS event
ORDER BY event.id DESC
```
(it's GMT time)

## Impact on other projects

I changed the CI of openfoodfacts-query to use `hetzner-02` as proxy to `hetzner-docker-prod` insteand of `hetzner-03`

I changed the CI of openfoodfacts-monitoring to use `hetzner-02` as proxy to `hetzner-docker-prod` insteand of `hetzner-03`

## Cleanup

I removed the virtiofs resource for hetzner-03.

I will discard hetzner-03, so no need to cleanup ZFS volumes there (yet).
