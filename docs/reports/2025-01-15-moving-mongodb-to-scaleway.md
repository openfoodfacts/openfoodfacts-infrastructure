# 2025-01-15 Moving mongoDB (and redis and postgers) to scaleway

We are moving MongoDB service to scaleway.

I decided to use docker compose deployement of off-shared service.

This is because, as already said [in this dicussion](https://github.com/openfoodfacts/openfoodfacts-infrastructure/discussions/586):
1. we use an old version, so if we want to deploy it on a recent proxmox we would need to do it in a VM (and not a container), while docker compose is feasible as it has less dependency on kernel (does not need to run system services as opposed to a container)
2. it's already running smoothly in staging and it makes things more consistent
3. thanks to virtiofs, docker volume can now be ZFS datasets and that's nice for backups, accessibility and so on

And because of this I decided to also deploy postgres and redis (though data migrations would be phased).

## Preparing scaleway docker prod

I just need to add the ZFS dataset for mongoDB data `off_shared_mongodb_data`
(I want to isolate them). We create it on nvme,
but we mount it at the right place so that it is visible in the VM

I decided not to do a volume for redis yet, as it can well live in the upper dataset.
Both needs to be on the SSD.

I will do the same for the postgres data volume: `off_shared_pg_data`

I did this setting using ansible with tags zfs

I verified that the volume is visible and writable in the VM.

## Deploying stunnel on the reveres proxy

We will need stunnel server so that services on off1/off2 as well on ovh / hetzner, etc.
connects to mongodb and redis.

This is not currently implemented in ansible so we added it.



## TODO
1. créer profile pour prod-mongo / stagging / run
2. enlever le docker-compose inutile si besoin
2. cloner dataset pour mongo (à la mano)
2. expsore dataset avec virtiofs (ansible)
3. créer le deploy sur la VM scaleway docker prod
4. config stunnel client (off2, autre tunnels, chercher dans les configs) et server sur scaleway
5. vérifier accessiblité depuis off, et depuis les autres stunnel clients (sur un port temporaire, on fera le switch sur le port actuel du mongo lors de la balance)
6. préparer la bascule
   - bascule configs off
   - bascule des configs stunnel client pour off-query / robotoff