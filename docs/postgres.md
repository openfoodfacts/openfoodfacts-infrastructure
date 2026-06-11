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

## Using PgHero to monitor databases

Both the off-query and shared services PostgreSQL database have monitoring enabled.

It is possible to connect to these databases using PgHero to examine query statistics to enable database tuning.

At the moment there is no specific user configured for PgHero, so you will need to know the superuser login and password to do this.

The steps to run PgHero locally are as follows:

### Connect with SSH using Local Forwarding

The easiest way to do this to use the SSH config file to configure a connection to a server that accesses the required PostgreSQL database and add a LocalForward rule to map the port locally, e.g. for off-query:

```
Host off-query
    Hostname 10.3.0.200
    ProxyJump off@45.147.209.254
    IdentityFile /home/{your user name}/.ssh/id_rsa
    LocalForward 5513 localhost:5512
```

The first number (5513 in the example above) can be any free port on your local machine.

### Run PgHero

This can be done using the PgHero docker container. Once the above SSH connection has been established, you can start PgHero with a command line like this:

```
docker run -ti --add-host=host.docker.internal:host-gateway -e DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@host.docker.internal:5513/query -p 8203:8080 ankane/pghero
```

This assumes that the superuser name and password are set as environment variables. The `host.docker.internal` clauses allow the running container to see the mapped port on your local machine, this might not be needed depending on the type of docker networking you use. The port (e.g. 5513) needs to match the one in your SSH config and the mapped port (e.g. 8203) needs to be another free port on your machine. Once this has been run you can access PgHero using the following URL:

http://localhost:8203/
