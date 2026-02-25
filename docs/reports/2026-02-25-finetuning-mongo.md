# 2026-02-25 Finetuning MongoDB serveur

As mongo does not seems to be so active on the new scaleway server,
I was asking myself if some optimizations needs to be done.

## Adding memory

I added some memory to MongoDB wiredtiger cache from 32G to 64G.

This gave this PR: https://github.com/openfoodfacts/openfoodfacts-shared-services/pull/31

## Fixing some kernel settings

Logging in mongo I saw those messages:
```
# sudo -u off docker compose exec mongodb mongo
...
---
The server generated these startup warnings when booting: 
        2026-02-25T15:57:57.890+00:00: Access control is not enabled for the database. Read and write access to data and configuration is unrestricted
        2026-02-25T15:57:57.891+00:00: /sys/kernel/mm/transparent_hugepage/enabled is 'always'. We suggest setting it to 'never'
        2026-02-25T15:57:57.891+00:00: Soft rlimits too low
        2026-02-25T15:57:57.891+00:00:         currentValue: 1024
        2026-02-25T15:57:57.891+00:00:         recommendedMinimum: 64000
---
> 
```

So I decided to fix it.

### Fixing hugepage

I did:
```bash
cat never > /sys/kernel/mm/transparent_hugepage/enabled
```
but it won't survive a reboot,
* so I edited `/etc/default/grub` to add:
  `transparent_hugepage=never` in `GRUB_CMDLINE_LINUX`
* and then recreate grub config. issuing: `update-grub`

### Fixing rlimits

This is at the docker compose level.
We can see
* that indeed default soft limits are thight, using `ulimit -a -S`
* but that open files hard limit is high, using `ulimit -a -H`
so we just have to set the right limit for our docker container,
thanks to the `ulimits` section.
(use `man getrlimit` to understand possible values. instead of `RLIMIT_NOFILE`, simply use `nofile`)

To verify our docker compose config works,
we can start the container, use `docker compose exce mongodb bash -c "ulimit -a"`
to see limits.

This gave this PR: https://github.com/openfoodfacts/openfoodfacts-shared-services/pull/32