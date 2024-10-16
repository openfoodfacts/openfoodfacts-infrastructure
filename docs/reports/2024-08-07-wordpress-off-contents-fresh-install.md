# 2024-08-07-wordpress-off-contents-fresh-install

We had a contents container on OVH with a wordpress install.
But we wanted to wipe it out and install it again.

## Wiping the old wordpress

```bash
cd /var/www/html
wp db clean --yes
rm -rf /var/www/html
```

## Change mariadb root password

```bash
sudo systemctl stop mariadb
sudo mysqld_safe --skip-grant-tables &
mysql -u root mysql
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '*******';
FLUSH PRIVILEGES;
EXIT;
sudo systemctl start mariadb
```

## Change mariadb wp user password

```bash
mysql -u root -p
ALTER USER 'wp'@'localhost' IDENTIFIED BY '********';
FLUSH PRIVILEGES;
EXIT;
```

## Install last wordpress version

```bash
sudo chown -R www-data:www-data var/www/html
sudo chmod -R 755 /var/www/html
cd /var/www/html
sudo -u www-data wp core download
```

## Wordpress Configuration

Settings > Reading > Search engine visibility > tick "Discourage search engine from indexing this site"<br>
Settings > Permalinks > Permalink structure > chose 'Post name'

Later on we also added a basic auth on reverse proxy with off:off just in case.