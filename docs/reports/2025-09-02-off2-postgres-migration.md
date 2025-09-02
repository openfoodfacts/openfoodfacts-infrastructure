# 2025-09-02 OFF2 Postgres Upgrade

We want to upgrade to postgres > 16 on the production postgresql instance.

This is important for keycloak integration.

## Preambule

I first created a snapshot, on off2:
```bash
sudo zfs snapshot zfs-hdd/pve/subvol-120-disk-0@2025-09-02-alex-pg-migration-1
```

Also I can check current clusters on my machine:

```bash
pg_lsclusters
Ver Cluster Port Status Owner    Data directory              Log file
13  main    5432 online postgres /var/lib/postgresql/13/main /var/log/postgresql/postgresql-13-main.log
```

## Installing postgres APT repositories

We want to use postgres repositories providing debian packages,
because our debian version does not include PG 16 or more.

For this on off-postgres container,
I added the sources for postgres as explained in https://www.postgresql.org/download/linux/debian/

I checked that our debian release (`lsb_release -a`) is supported.

I started by a system upgrade to be sure to have correct packages versions.

I used the automated install (note: I had to add gnupg2 package):
```bash
sudo apt install -y postgresql-common gnupg2
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh
```

Check:
```bash
apt update
```

## Upgrading

Now I can see updates even on current postgres version using `apt list --upgradable`,
I will apply for them.
```bash
apt upgrade
```
This automatically proposes to upgrade the cluster to version 17
(because package postgres is installed):
```curse
Package configuration                                                                               
                                                                                                    
   ┌─────────────────────────────────┤ Configuring postgresql ├─────────────────────────────────┐   
   │                                                                                            │   
   │ The PostgreSQL database cluster 13/main can be upgraded to version 17, this will be        │   
   │ attempted now. (If no automated cluster upgrades are desired, uninstall the "postgresql"   │   
   │ meta package.)                                                                             │   
   │                                                                                            │   
   │ Alternatively, the cluster can later be upgraded by running the command:                   │   
   │                                                                                            │   
   │   pg_upgradecluster 13 main -v 17                                                          │   
   │                                                                                            │   
   │                                                                                            │   
   │ Once the upgraded cluster has been validated to work, drop the old cluster using the       │   
   │ command:                                                                                   │   
   │                                                                                            │   
   │   pg_dropcluster 13 main                                                                   │   
   │                                                                                            │   
   │                                           <Ok>                                             │   
   │                                                                                            │   
   └────────────────────────────────────────────────────────────────────────────────────────────┘   
                                                                                                    
```

Just before validating, I take a snapshot on off2:
```bash
sudo zfs snapshot zfs-hdd/pve/subvol-120-disk-0@2025-09-02-alex-pg-migration-2
```

Migration took about 1:50 minutes, with most part spent in keycloak migration.

### Testing migration

To test migration was ok I:
* logged in to https://auth.openfoodfacts.org/admin/master/console/ with my admin account
  * choosed Open Food Facts realm (top left select box in the interface)
  * looked at users - listing is working
* tested I can log in https://world.new.openpetfoodfacts.org/ (test instance for keycloak)

## Cleaning

I will have to log in a few days to clean the pg cluster version 13 and it's data and the backup snapshots I took.

