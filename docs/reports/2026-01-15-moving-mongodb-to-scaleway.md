# 2025-01-15 Moving mongoDB (and redis and postgers) to scaleway

We are moving MongoDB service to scaleway.

I decided to use docker compose deployement of off-shared service.

This is because, as already said [in this dicussion](https://github.com/openfoodfacts/openfoodfacts-infrastructure/discussions/586):
1. we use an old version, so if we want to deploy it on a recent proxmox we would need to do it in a VM (and not a container), while docker compose is feasible as it has less dependency on kernel (does not need to run system services as opposed to a container)
2. it's already running smoothly in staging and it makes things more consistent
3. thanks to virtiofs, docker volume can now be ZFS datasets and that's nice for backups, accessibility and so on

And because of this I decided to also deploy postgres and redis (though data migrations would be phased).

We also have the chance that current mongo has a separated volume for data (`subvol-102-disk-0`) (thanks to myself from the past). We might have to move things around (because instead of db/ we should have directly the data) and change owner, but that's a fast operation.

## Deploying scaleway docker prod

### Preparing scaleway docker prod

I just need to add the ZFS dataset for mongoDB data `off_shared_mongodb_data`
(I want to isolate them). We create it on nvme,
but we mount it at the right place so that it is visible in the VM

I will do the same for the redis and postgres data volume: `off_shared_pg_data`
`off_shared_redis_data` because I need both on SSD.

I did this setting using ansible with tags zfs
`ansible-playbook sites/proxmox-node.yml -l scaleway-02 --tags zfs`

I verified that the volume is visible and writable in the VM.

### Changing deploy script


I did:
- create a private key (`ssh-keygen -t ed25519 -C "root+off-shared-prod-key@openfoodfacts.org" -f off-shared-prod-key`)
- add it to off-passworld keepassX
- add a private key to github settings shared-org
- the public key will be added to ss_public_keys for continuous deployment role in `ansible/host_vars/scaleway-docker-prod/docker.yml` and run `ansible-playbook sites/docker_vm.yml -l scaleway-docker-prod --tags cd`

I also took the opportunity to add POSTGRES_PASSWORD using the one in production,
and add a PG_BOOTSTRAP_PASSWORD (randomly generated)

I also have to understand how to setup some variables.

On the current MongoDB container, I use `systemctl cat mongod.service`
to see that conf is in `/etc/default/mongod` and `/etc/mongod.conf`
and there are no real fine tunning, except a `MONGODB_CONFIG_OVERRIDE_NOFORK=1`
directly in the service definition.

See https://github.com/openfoodfacts/openfoodfacts-shared-services/pull/23 for the new deploy action.

## Deploying stunnel on the reveres proxy

We will need stunnel server so that services on off1/off2 as well on ovh / hetzner, etc.
connects to mongodb and redis.

This is not currently implemented in ansible so we added it.


## Note PM on wrong volume name created

I first created the volume with wrong name (redis_data instead of redisdata).

I fix tart by editing in `ansible/host_vars/scaleway-02/proxmox.yml`,
adding:
```yaml
  - name: zfs-nvme/virtiofs/qm-200-off_shared_redis_data
    state: absent
  - name: zfs-nvme/virtiofs/qm-200-off_shared_redisdata
    properties:
      # we need to mount it in the right place for docker in the VM
      mountpoint: /zfs-hdd/virtiofs/qm-200/docker-volumes/off_shared_redisdata
```
and replaying ``ansible-playbook sites/proxmox-node.yml -l scaleway-02 --tags zfs`

Still the deployment was failing with:
```
off_shared_redisdata/_data': failed to mount local volume: mount /srv/off/docker_data/off_shared_redisdata:/var/lib/docker/volumes/off_shared_redisdata/_data, flags: 0x1000: no such file or directory
```
This is because it might have initialized it before I mount the new ZFS (John did a commit in between).

To deal with it, `scaleway-docker-prod`:
```
# volume exists
$ docker volume list |grep off_shared_redisdata
local     off_shared_redisdata
# first try to remove
$ docker volume rm off_shared_redisdata
Error response from daemon: remove off_shared_redisdata: umount /var/lib/docker/volumes/off_shared_redisdata/_data, flags: 0x2: no such file or directory
# create the _data folder to make docker happy (otherwise it will refuse to remove the volume)
$ mkdir -p /var/lib/docker/volumes/off_shared_redisdata/_data
# remove the volume (it will fail because it can't remove the parent folder, but it's ok)
$ docker volume rm off_shared_redisdata
# it's not there anymore
$ docker volume list |grep off_shared_redisdata
# stop here, I will let the deploy script re-create it
```
We also have a similar yet different problem with pg_data volume (because of a if condition, we created it as if on staging where it is deported, while it should not).
So we apply the same fix.


## TODO
1. [DONE] modify docker compose of off-shared service
2. [DONE] modify ci deploy scripto  of off-shared service to deploy to scaleway
3. [DONE] create zfs datasets corresponding to docker volumes on scaleway-02 (ansible)
3. [DONE] deploy with CI on scaleway-02 for prod
2. clone prod mongo dataset backup and use it as docker volume dataset
   * changer le path /db pour /
   * changer les permissions
5. config stunnel server server on scaleway for mongo / postgres / redis
4. config stunnel client (off2, other tunnels, search in configs)
   and verify service is accessible for off / obf / opf etc. and other services that needs it
6. prepare for switch
   - switch o*f configs
   - replace old  stunnel client port for off-query / robotoff