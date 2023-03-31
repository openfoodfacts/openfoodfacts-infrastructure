# MongoDB

MongoDB is the database used to search products and run aggregations (like facets), etc.

We have a single instance in production.

For staging also we have a single instance.

## Refresh products scripts

The machine with MongoDB must have a product opener clone to be able to run [`refresh_products_tags.js`](https://github.com/openfoodfacts/openfoodfacts-server/blob/640c6d1d8c121bbe2987e4811a555b9305ae2a62/scripts/refresh_products_tags.js) in crontab.

This creates small collections that are used for aggregations (mainly for facets for anonymous users).

## Staging (aka Dev) instance

This is an instance for staging (aka .net) product opener instances.

It is deployed on [staging containers VM](./docker_architecture.md#docker-server-for-staging).

See https://github.com/openfoodfacts/openfoodfacts-server/blob/main/.github/workflows/mongo-deploy.yml script.



## Prod instance

We installed the [MongoDB Community Edition Packages](https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-debian/#std-label-debian-package-content) for Debian.

The configuration file is in `/etc/mongod.conf`.

* `storage.dbPath` is set to a specific volume: `/mongo/db`
* `systemLog.LogRotate` is set to `reopen`
* `processManagement.pidFilePath` is set to `"/var/run/mongodb/mongod.pid"`
  (strangely it's not set by default while `/lib/systemd/system/mongod.service` uses this path)

I also had to create the `/var/run/mongodb` directory and give it to `mongodb` user:

```bash
mkdir /var/run/mongodb/
chown mongodb:mongodb /var/run/mongodb/
```

### Log rotate

In production, logs have to be rotated[^stagging_no_log_rotate].

Following [this blog post](https://www.zoonman.com/blog/mongodb-logrotated/) cross checked with official docs.

See above to configure `/etc/mongod.conf` correctly.

Then `/etc/logrotate.d/mongod`:
```
/var/log/mongodb/mongod.log
{
   rotate 7
   daily
   size 100M
   missingok
   create 0600 mongodb mongodb
   delaycompress
   compress
   sharedscripts
   postrotate
     /bin/kill -SIGUSR1 $(cat /var/run/mongodb/mongod.pid)
   endscript
}
```

We also have logs for refresh products tags `/etc/logrotate.d/mongo_refresh_tags`:
```
/var/log/mongodb/refresh_products_tags_*.log
{
  rotate 7
  weekly
  size 100M
  missingok
  delaycompress
  compress
}
```

```

[^stagging_no_log_rotate]:
    On staging logs are sent to docker stdout/err and we let docker handle logs.
