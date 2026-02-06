# Upgrade of Label Studio

Label Studio is a data labeling tool that we use for annotating datasets. We're currently using version 1.13.

Version 1.14 migrates from Django 3 to Django 4, we therefore need to migrate first to version 1.14 before upgrading to the latest version (1.22
 as of January 2026). Version 1.14 requires Postgresql 12 or higher. We are currently using Postgresql 1.11.5, so we will also need to upgrade our database server.

Version 1.16 migrates to Django 5, which requires Postgresql 13 or higher.

We can then migrate to version 1.22.0, which is the latest stable version as of January 2026.

## Migration Plan

### Step 1: Backup data

Let's backup the two volumes used by Label Studio:

- app storage (label-studio-org_app-storage)
- database storage (label-studio-org_db-storage)

Following [Docker documentation](https://docs.docker.com/engine/storage/volumes/#back-up-a-volume), after stopping the containers, we can create tarballs of the volumes:

```bash
docker run --rm --volumes-from label-studio-org-db-1 -v $(pwd):/backup ubuntu tar cvzf /backup/db_backup.tar.gz /var/lib/postgresql/data
docker run --rm --volumes-from label-studio-org-app-1 -v $(pwd)/backups:/backup ubuntu tar cvzf /backup/app_backup.tar.gz /label-studio/data
```

### Step 2: Upgrade Postgresql to version 12.22

```
docker exec -it label-studio-org-db-1 pg_dumpall -U postgres > dump.sql
```

Then, stop the container. Remove all data in the `label-studio-org_db-storage` volume.

Upgrade the `docker-compose.yml` file to use Postgresql 12:

```yaml
services:
  db:
    image: postgres:12.22
```

Pull latest version of the db service and relaunch it. Make sure it is running properly.

Then, import the dump file:

```bash
docker exec -i label-studio-org-db-1 psql -U postgres < dump.sql
```

Make sure that the DB service runs correctly after the upgrade.

### Step 3: Upgrade to Label Studio 1.14

Update the `docker-compose.yml` file to use Label Studio version 1.14:

```yaml
services:
  label-studio:
    image: heartexlabs/label-studio:1.14.0
```

Pull the new image, and relaunch the Label Studio service.

### Step 4: Upgrade Postgresql to version 17.7

Perform the same steps as in Step 2, but this time upgrade to Postgresql 17.7.
There was a single error while importing the dump file related to a malformed JSON value during the import of a prediction. As it was not critical, we ignored it.

### Step 5: Upgrade to Label Studio 1.22.0

Perform the same steps as in Step 3, but this time upgrade to Label Studio version 1.22.0.


## Conclusion

The upgrade was successful. Label Studio is now running version 1.22.0 with Postgresql 17.7.
As a note, we could have directly upgraded to Postgresql 17.7 in Step 2, as Label Studio 1.14 supports Postgresql 12 and higher.