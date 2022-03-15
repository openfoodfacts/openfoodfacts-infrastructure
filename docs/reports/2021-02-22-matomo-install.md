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