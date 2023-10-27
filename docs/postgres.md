# PostgreSQL

PostgreSQL is a database used in various sub projects at open food facts.

## Production deployment

### Docker compose projects

Docker compose based projects like robotoff or openfoodfacts-query use their own instance of the database in docker containers.

If data in the database is the primary source,
it is advised to have a backup volume (typically a nfs or zfs volume) to backup the database regularly with a pg_dump.
It might be more reliable and manageable than to only rely on the filesystem snapshot made by Proxmox/ZFS.

### Product Opener

For Product Opener instances we only use the postgreSQL for minions tasks.

It is in a Proxmox container, right now there is no customization.
Backup and is not a thing as it is transient data.

**TODO:** at least have data in a ZFS volume (through a bind mount) ?

