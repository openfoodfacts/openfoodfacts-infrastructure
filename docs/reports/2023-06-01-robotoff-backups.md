# 2023-06-01 Robotoff backups

So far, Robotoff backups were performed manually. We wish to automate the process.

I created a zfs dataset for Robotoff backups:

`zfs create rpool/backups/robotoff`

I updated the dataset `sharenfs` settings to allow nfs mount from 10.1.0.201:

`zfs set sharenfs='rw=@10.0.0.0/28,rw=@10.1.0.201/32,no_root_squash' rpool/backups/robotoff`

The NFS share was then mounted as a docker volume on Robotoff instance. (see https://github.com/openfoodfacts/robotoff/pull/1127)
