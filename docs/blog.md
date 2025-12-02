

## Key points

Open Food Facts blog is based on [WordPress](https://wordpress.org/) CMS.

It is hosted on a Debian 11 server with Apache2, PHP-FPM and MariaDB.

It is installed on a LXC container managed by Proxmox VE: CT 140 on ovh1 server.


## Good practices

* We don't install too much plugins, to avoid security issues and performance problems.
* Every new plugin should be discussed with the team before installation.
* We use a staging environment to test updates before applying them on production.


## Technical administration

Wordpress is auto-updated thanks to internal Wordpress update system.

Fail2ban is installed on the reverse proxy to protect against brute-force attacks.

One a year, we should have a look at the latest PHP versions and consider upgrading if relevant, see: https://www.php.net/supported-versions.php


## Installation

```bash
# From a fresh Debian 11 installation
apt update
apt upgrade
apt install sqlite3 htop iftop recode screen git wget curl lynx sudo
apt install apache2 libapache2-mod-fcgid
apt install php-{fpm,cli,curl,gd,imagick,imap,json,mbstring,mysql,xml,zip} mariadb-server
a2enconf php7.4-fpm
a2enmod proxy_fcgi setenvif
systemctl restart apache2
a2enmod deflate # allow gzip compression
a2enmod rewrite # activate mod_rewrite module (needed by many CMS (wordpress, mediawiki...))
systemctl restart apache2
systemctl status mariadb
systemctl enable mariadb
mysql_secure_installation

# Modify php.ini:
# upload_max_filesize = 50M

systemctl restart php7.4-fpm.service

dpkg-reconfigure locales # choose en_US.UTF-8

```

Installation of Sury repository to get multiple PHP versions and switch between them (2025-11):

```bash
# Install PHP from Sury repository to get multiple PHP versions
apt install extrepo
extrepo enable sury # we use https://deb.sury.org/ repository to get multiple PHP versions
apt update

apt install php7.4-{cli,common,curl,fpm,gd,imagick,imap,intl,json,mbstring,mysql,opcache,readline,xml,zip}
apt install php8.4-{cli,common,curl,fpm,gd,imagick,imap,intl,mbstring,mysql,opcache,readline,xml,zip}

# Setup generic php-fpm to allow switching between versions
nano /etc/apache2/conf-available/fpm-generic.conf
#<FilesMatch \.php$>
#    SetHandler "proxy:unix:/run/php/php-fpm.sock|fcgi://localhost/"
#</FilesMatch>

# Plus, if necessary, remove existing <FilesMatch>... </FilesMatch> blocks in other config files
# See: grep -r 'php7.4-fpm.sock' /etc/apache2/

a2disconf php7.4-fpm
a2enmod proxy proxy_fcgi setenvif
a2enconf fpm-generic
systemctl restart apache2

update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/lib/php/7.4/sapi/fpm 74
update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/lib/php/8.4/sapi/fpm 84

# To switch between PHP versions:
update-alternatives --set php-fpm /usr/lib/php/8.4/sapi/fpm
update-alternatives --set php /usr/bin/php8.4
systemctl restart php8.4-fpm
systemctl stop php7.4-fpm

# Get back to PHP 7.4
update-alternatives --set php-fpm /usr/lib/php/7.4/sapi/fpm
update-alternatives --set php /usr/bin/php7.4
systemctl restart php7.4-fpm
systemctl stop php8.4-fpm

# or
update-alternatives --config php-fpm
update-alternatives --config php

# Verify
php -v

```

## Staging environment

All tests will be made on a staging machine based on proxmox cloning:
```bash
# create a "temp" named snapshot of CT with ID 140 (production): don't forget
# to give it a unique name (e.g. with date)
pct snapshot 140 temp_20251125
pct shutdown 141 # shutdown 141 machine
pct destroy 141 # delete target machine
pct clone 140 141 --hostname wp-staging --snapname temp_20251125 # take the snapshot and create a new CT (141) named wp-staging
pct delsnapshot 140 temp_20251125 # del production snapshot
# New CT configuration
pct set 141 --cores 2 --memory 1024 --net0 name=eth0,bridge=vmbr0,gw=10.0.0.1,ip=10.1.0.141/24
pct start 141

lxc-attach -n 141 -- sudo -H -u www-data bash -c "wp option update home 'https://test-blog.openfoodfacts.org' --path=/var/www/html"
lxc-attach -n 141 -- sudo -H -u www-data bash -c "wp option update siteurl 'https://test-blog.openfoodfacts.org' --path=/var/www/html"
```

