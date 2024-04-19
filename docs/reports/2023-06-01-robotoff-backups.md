# 2023-06-01 Robotoff backups

So far, Robotoff backups were performed manually. We wish to automate the process.

On ovh3, I created a zfs dataset for Robotoff backups:

`zfs create rpool/backups/robotoff`

I updated the dataset `sharenfs` settings to allow nfs mount from 10.1.0.201:

`zfs set sharenfs='rw=@10.0.0.0/28,rw=@10.1.0.201/32,no_root_squash' rpool/backups/robotoff`

The NFS share was then mounted as a docker volume on Robotoff instance. (see https://github.com/openfoodfacts/robotoff/pull/1127)

## Adding snapshot with sanoid

In /etc/sanoid/sanoid.conf We added:

```conf
[rpool/backups/robotoff]
  use_template=prod_data
  recursive=no
```
(and tweaked a bit the retention policy).

Wait until sanoid is launched.

Commit changes:
```bash
cd /opt/openfoodfacts-infrastructure
git status
git diff
git commit -a -m "feat: added robotoff backups + review retention" --author "Alex Garel …"
```
**Note:** because of current off2 migration, this was pushed to that branch.