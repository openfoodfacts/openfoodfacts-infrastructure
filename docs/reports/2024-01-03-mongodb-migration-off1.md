# 2024-01-03 MongoDB migration on off3

## Context

To [upgrade off2](./2023-02-17-off2-upgrade.md), we moved MongoDB to a VM kindly provided by Open Street Map France (VM codename off3) on a server located in the same datacenter.

We Then moved all the stuff from off1 to off2. We then [upgrade off1](./2023-12-08-off1-upgrade.md).

It's now time to move back MongoDB instance to the upgraded off1 server. It will be installed in a container as we now use [proxmox](../promox.md)

## Creating a container

We followed usual procedure to [create a proxmox container](../promox.md#how-to-create-a-new-container):
* of id 102
* choosed a debian 10 (**important**: org version of mongodb 4.4 is not available in newly debian versions)
* default storage on zfs-hdd (for system) 30Gb, noatime
* add another storage mountpoint 0, on zfs-nvme mounted as /mongo with 96 Gb, noatime
* 15 cores
* memory 131072 Mb (128 Gb), no swap

Before running the ctpostinstall script, I had to change buster in sources list to oldoldstable.

I also [configured email](../mail.md#postfix-configuration) in the container.

I also immediately created a off user for it to have id 1000.

## Installing MongoDB

We follow [MongoDB 4.4 install procedure](https://www.mongodb.com/docs/v4.4/tutorial/install-mongodb-on-debian/)


```bash
sudo apt-get install gnupg curl
curl -fsSL https://pgp.mongodb.com/server-4.4.asc | \
   sudo gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg \
   --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] http://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
sudo apt-get update
sudo apt-get install -y mongodb-org

sudo systemctl daemon-reload
sudo systemctl enable mongod
sudo systemctl start mongod
# verify
sudo systemctl status mongod
```

## cloning repos

### Infrastructure repository

Create root ssh key: `ssh-keygen -t ed25519 -C "root@mongodb"`

Added root ssh pub key (`cat /root/.ssh/id_ed25519.pub`) as a [deploy key to github infrastructure repository](https://github.com/openfoodfacts/openfoodfacts-infrastructure/settings/keys)


Cloned
```bash
cd /opt
git clone git@github.com:openfoodfacts/openfoodfacts-infrastructure.git
```

### OFF server repository

We need Product Opener repository to get scripts we need to run routinely.

We can't use the same certificate for the git repository…

Create root ssh key: `ssh-keygen -t ed25519 -C "root+off-server@mongodb" -f /root/.ssh/github_off-server -N ''`

Added root ssh pub key (`cat /root/.ssh/github_off-server.pub`) as a [deploy key to github server repository](https://github.com/openfoodfacts/openfoodfacts-server/settings/keys)

Modified git config to use right key to connect to the repository:

```bash
vim /root/.ssh/config
...
Host github.com-off-server
  Hostname github.com
  IdentityFile=/root/.ssh/github_off-server
```

Cloned:

```bash
cd /opt
git clone git@github.com-off-server:openfoodfacts/openfoodfacts-server.git
```


## Setting up

First I copied the off1 root public certificate to authorized_keys on off3, and ssh once to validate the key.

I stopped mongodb: `systemctl stop mongod`


Then I prepared the directory for mongodb data:

```bash
mkdir /mongo/db
chown mongodb:mongodb /mongo/db
rmdir /var/lib/mongodb
ln -s /mongo/db /var/lib/mongodb
```

Copied mongodb config from off3. On off1, as well as logrotate configs:

```bash
# mongodb config
rsync 10.0.0.3:/etc/mongod.conf /zfs-hdd/pve/subvol-102-disk-0/opt/openfoodfacts-infrastructure/confs/mongodb/
# logrotate configs
rsync 10.0.0.3:"/etc/logrotate.d/mongo*" /zfs-hdd/pve/subvol-102-disk-0/opt/openfoodfacts-infrastructure/confs/mongodb/logrotate.d/
```


Linked the config: 
```bash
mv /etc/mongod.conf{,.dist}
ln -s /opt/openfoodfacts-infrastructure/confs/mongodb/mongod.conf /etc/mongod.conf
ln -s /opt/openfoodfacts-infrastructure/confs/mongodb/logrotate.d/mongod /etc/logrotate.d/
ln -s /opt/openfoodfacts-infrastructure/confs/mongodb/logrotate.d/mongo_refresh_tags /etc/logrotate.d/
```

And restart mongodb `systemctl start mongod`

And check `systemctl start mongod`

### setting up cron jobs





## Migrating data for a test

We use rsync to get data from off3.

Then I 

