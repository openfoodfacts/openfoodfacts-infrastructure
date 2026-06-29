# 2026-06-26 Repman test

We are testing [replication manager by signal18](https://docs.signal18.io/).


## Creating data

I have generated a file with a script to feed the mariadb.
I split in 5 files (`split -n l/5  --additional-suffix .sql import_products.sql import_products.split.`)


## Install

### Create containers

I created a repman-test1 and repman-test2 containers on hetzner-02.

### Install replication-manager

I followed [`2.1.4.3.1 Configure the repository and install`](https://docs.signal18.io/installation/setup-instructions/repository) on repman-test1, as root:
```bash
# Set version
version="3.1"

# Import GPG signing key
gpg --recv-keys --keyserver keyserver.ubuntu.com FAE20E50
gpg --export FAE20E50 > /etc/apt/trusted.gpg.d/signal18.gpg

# Add repository
echo "deb [signed-by=/etc/apt/trusted.gpg.d/signal18.gpg] http://repo.signal18.io/deb $(lsb_release -sc) $version" \
  > /etc/apt/sources.list.d/signal18.list

# Install
apt-get update
    ...
    Get:10 http://repo.signal18.io/deb trixie InRelease [19.6 kB]
    Get:11 http://repo.signal18.io/deb trixie/3.1 amd64 Packages [7917 B]
    Fetched 525 kB in 0s (2494 kB/s)
    ...
apt-get install replication-manager-osc
```

I don't enable yet the service, until I have configured it !

### Install MariaDB

On both server:
```bash
apt install mariadb-server
systemctl status mariadb
```

Make it serve publicly by adding `/etc/mysql/mariadb.conf.d/99-listen-public.cnf` with:
```ini
[mysqld]
bind-address = 0.0.0.0
skip-name-resolve
```
and in `/etc/mysql/mariadb.conf.d/99-bin-log.cnf`
```ini
[mysqld]
log_bin
```
and
```bash
systemctl restart mariadb
```

### Create users

following https://docs.signal18.io/installation/database-grants

Create the admintest user on both:
```SQL
CREATE USER 'admintest'@'10.12.1.%' IDENTIFIED BY '****************';

GRANT SELECT, PROCESS, RELOAD,
      REPLICATION CLIENT, REPLICATION SLAVE,
      BINLOG MONITOR,
      REPLICATION SLAVE ADMIN,
      SLAVE MONITOR,
      REPLICATION MASTER ADMIN,
      READ_ONLY ADMIN,
      CONNECTION ADMIN
  ON *.* TO 'admintest'@'10.12.1.%';

GRANT ALL PRIVILEGES
  ON replication_manager_schema.*
  TO 'admintest'@'10.12.1.%';
FLUSH PRIVILEGES;
```
NOTE: I added SALVE MONITOR

Create the  user on both:
```SQL
CREATE USER 'repltest'@'10.12.1.%' IDENTIFIED BY '****************';

GRANT REPLICATION SLAVE ON *.* TO 'repltest'@'10.12.1.%';

FLUSH PRIVILEGES;
```

On repman-test1, I also created the replication_manager_schema access:
```SQL
CREATE DATABASE IF NOT EXISTS replication_manager_schema;

GRANT ALL PRIVILEGES
  ON replication_manager_schema.*
  TO 'admintest'@'10.12.1.%';
```

On repman-test1 instance I created a database:
```SQL
CREATE DATABASE off;
```
And fed the first data file (see below).
```bash
mariadb off < import_products.split.aa.sql
```

```
mariadb off
> select count(*) from products;
+----------+
| count(*) |
+----------+
|       92 |
+----------+
1 row in set (0.000 sec)
```

from repman-test1 I can test access to both instances:
```bash
nc -vz 10.12.1.114 3306
nc -vz 10.12.1.115 3306
mariadb -h 10.12.1.114 -u admin1 --skip-ssl -p
mariadb -h 10.12.1.115 -u admin1 --skip-ssl -p
```

## Configure

In `/etc/replication-manager/config.toml`,
`monitoring-save-config` is false for now, and that's what we want.

I chane `api-credentials=admin:*****` to add a real password.
And uncomment http-server section:
```ini
http-server = true
http-bind-address = "0.0.0.0"
http-port = "10001"
```

Create `/etc/replication-manager/cluster.d/test.toml` with the content:
```toml
[cluster_test]
title                       = "off-test"
prov-orchestrator           = "onpremise"
db-servers-hosts            = "10.12.1.115:3306,10.12.1.114:3306"
db-servers-prefered-master  = "10.12.1.115:3306"
db-servers-credential       = "admintest:**************"
replication-credential      = "repltest:******"
```

## Start

I started with:
`systemctl enable --now replication-manager`

I can see replication is running with
```bash
replication-manager-cli status
```
(you must use API password)

```bash
replication-manager-cli topology
```
show mariadb servers

```bash
replication-manager-cli console --cluster=cluster_test
```
is a TUI

### Access dashboard

```bash
ssh repman-test1 -L 10001:127.0.0.1:10001
```
in a browser open: http://127.0.0.1:10001
and logged in with the API user admin / password defined above.

### Bootstrap replication

in dashboard, my servers are "suspect", this is because I only have two server,
so quorum is not ok for election.
So I force the replication resolution:
```bash
replication-manager-cli bootstrap --cluster=cluster_test --topology=master-slave
```

## Next steps

Save files that are meaningful and do not contains secrets in git:
`/etc/replication-manager/config.toml`

See Use 8.2.2 Configuration File Security to secure passwords,
and using a key + encryption of passwords in configuration files.
Or maybe, just add a file without section with same name as config + secrets (as it will add up to current section).