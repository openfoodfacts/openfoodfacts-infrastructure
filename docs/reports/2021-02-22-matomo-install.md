# Matomo install

see: https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/24

## Install log

Nginx and SSL configuration for https://analytics.openfoodfacts.org/:

```
$ ssh -i ~/.ssh/id_rsa -J CharlesNepote@ovh1.openfoodfacts.org CharlesNepote@10.1.0.101
$ sudo cp /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/analytics.conf
$ sudo nano /etc/nginx/conf.d/analytics.conf
access_log  /var/log/nginx/analytics.access.log  main;
server_name  analytics.openfoodfacts.org;

$ sudo systemctl restart nginx
$ sudo certbot
https://analytics.openfoodfacts.org/
```

make a snapshot before
https://www.atechtown.com/install-nginx-and-php-on-debian-10/

```
$ ssh -i ~/.ssh/id_rsa -J CharlesNepote@ovh1.openfoodfacts.org CharlesNepote@10.1.0.107
$ sudo apt install nginx php7.3-{fpm,cli,curl,gd,imap,json,mbstring,mysql,xml,zip} mariadb-server
$ sudo chmod 755 -R /var/www/html/
$ sudo chown www-data:www-data -R /var/www/html/


$ sudo nano /etc/nginx/sites-available/default
location ~ \.php$ {
include snippets/fastcgi-php.conf;
```

With php-fpm (or other unix sockets):
```
fastcgi_pass unix:/var/run/php/php7.3-fpm.sock;
# With php-cgi (or other tcp sockets):
# fastcgi_pass 127.0.0.1:9000;
}
```
```
$ sudo systemctl restart nginx
$ echo "<?php phpinfo(); ?>" | sudo -u www-data tee /var/www/html/test.php
https://analytics.openfoodfacts.org/test.php
sudo rm /var/www/html/test.php

$ sudo systemctl enable mariadb
$ sudo mysql_secure_installation
# https://matomo.org/faq/how-to-install/faq_23484/
$ sudo mysql -e "CREATE DATABASE matomo_db;"
$ read matomopass # enter the matomo user password
$ sudo mysql -e "CREATE USER 'matomo'@'localhost' IDENTIFIED BY '$matomopass';"
$ sudo mysql -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, INDEX, DROP, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES ON matomo_db.* TO 'matomo'@'localhost';"
$ sudo mysql -e "GRANT FILE ON *.* TO 'matomo'@'localhost';"
$ unset matomopass
```

```
$ cd /var/www/html
$ sudo -u www-data wget https://builds.matomo.org/matomo.zip
$ sudo apt install unzip
$ sudo -u www-data unzip matomo.zip
$ sudo sed -i "s|root /var/www/html|/var/www/html/matomo|" /etc/nginx/sites-available/default

https://github.com/matomo-org/matomo-nginx/blob/master/sites-available/matomo.conf
$ sudo sed -i "s|index index.html index.htm index.nginx-debian.html;|index index.html index.htm index.nginx-debian.html index.php;|" /etc/nginx/sites-available/default # non!
$ sudo systemctl restart nginx
https://analytics.openfoodfacts.org
```

## Activate reverse proxy mode (2022-05-09)

We have to configure matomo to take into account it is behind a reverse proxy.

We follow https://matomo.org/faq/how-to-install/faq_98/

And on matomo machine (container 107):

1. edit `/var/www/html/matomo/config/config.ini` to add :
   ```
   [General]
   ...
   force_ssl = 1
   assume_secure_protocol = 1
   ...
   proxy_client_headers[] = HTTP_X_FORWARDED_FOR
   proxy_host_headers[] = HTTP_X_FORWARDED_HOST
   ```

2. restart pfm to take this into account:
   ```
   systemctl restart php7.3-fpm.service
   ```

On proxy machine (container 101), we insure the header is passed by nginx:

1. edit `/etc/nginx/conf.d/analytics.conf`
   ```
   server {
    server_name  analytics.openfoodfacts.org;
    ...
    location / {
        ...
        proxy_set_header  X-Forwarded-For $remote_addr;
   ```

2. reload nginx config:
   ```
   systemctl reload nginx
   ```

Verify it's working by looking at real time traffic on matomo.

## Trigger archival offline - 2022-05-10

By default matomo tries to run archival on analytics visit. But our website as a lot of analytics so it's important to run it on a regular basis and out of a request (which will timeout too soon).

We follow https://matomo.org/faq/troubleshooting/faq_19489/ and thus https://matomo.org/faq/on-premise/how-to-set-up-auto-archiving-of-your-reports/

On analytics (container 107):

- ensure [mail is setup correctly on the server](../mail.md#servers)

- create directory for logs:
  ```
  mkdir /var/log/matomo/
  chown www-data:www-data /var/log/matomo/
  ```


- edit  `/etc/cron.d/matomo-archive`

  ```
  MAILTO="root@openfoodfacts.org"
  5 * * * * www-data /usr/bin/php /var/www/html/matomo/console core:archive --url=http://analytics.openfoodfacts.org/ >> /var/log/matomo/matomo-archive.log 2>>/var/log/matomo/matomo-archive-err.log
  ```

- add files to logrotate, by adding `/etc/logrotate.d/matomo` with
  ```
  /var/log/matomo/*.log {
          daily
          missingok
          rotate 14
          compress
          delaycompress
          notifempty
          create 0640 www-data adm
          sharedscripts
  }
  ```

- tweak `/etc/php/7.3/cli/php.ini` (this correspond to settings for php command), to have:
  ```
  max_execution_time = 3000
  ...
  memory_limit = -1
  ```


In matomo (https://analytics.openfoodfacts.org), click on `Administration` → `System` → `General Settings`, and select:

- Archive reports when viewed from the browser: No
- Archive reports at most every X seconds : 3600 seconds

## Performance settings

I tweak `/etc/php/7.3/fpm/php.ini` to have:

```
max_execution_time = 120
...
memory_limit = 250M
```
then reload to take the change into account:
```
systemctl reload php7.3-fpm.service
```