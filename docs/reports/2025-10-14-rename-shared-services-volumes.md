# 2025-10-14 Renaming the shared services volumes

We want to rename the existing volumes while keeping the old ones up. To do this the general procedure is:

1. Create the new volume
2. Stop the service that is using the volume
3. Rename (mv) the existing volume device to the new volume directory
4. Create a symbolic link so the old volume directory points to the new one
5. Re-start the service

For Redis an explicit volume path was specified, so the script looks like this (without the start / stop service):

```sh
# Create the new volume
docker volume create --driver=local -o type=none -o o=bind -o device=/srv/off/docker_data/off_shared_redisdata off_shared_redisdata

# Move existing data to new volume
sudo mv /srv/off/docker_data/redis /srv/off/docker_data/off_shared_redisdata

# Create symbolic links from old volume directory to new one
sudo ln -sf /srv/off/docker_data/off_shared_redisdata /srv/off/docker_data/redis
```

For MongoDB the volume was created without a device (so data is stored in `/var/lib/docker/volumes`). In this case creating the volume creates the `_data` directory so we have to remove this first before renaming the existing directory:

```sh
# Create the new volume
docker volume off_shared_mongodb_data

# Move existing data to new volume
sudo rmdir /var/lib/docker/volumes/off_shared_mongodb_data/_data
sudo mv /var/lib/docker/volumes/dbdata/_data /var/lib/docker/volumes/off_shared_mongodb_data/_data

# Create symbolic links from old volume directory to the new one
sudo ln -sf /var/lib/docker/volumes/off_shared_mongodb_data/_data /var/lib/docker/volumes/dbdata/_data
```

We now have the originally named volume and the new volume both pointing to the same location.

Note that by keeping the data on the same device the `mv` commands are pretty quick so this could have been done in the deployment script without the need to retain teh old volume name.

Once the new version of shared-services has been deployed with the new volume names the old aliases can be deleted:

```sh
docker volume rm dbdata
docker volume rm po_redisdata

# Note have to delete the external device for redis (symlink to the new path)
sudo rm /srv/off/docker_data/redis
```
