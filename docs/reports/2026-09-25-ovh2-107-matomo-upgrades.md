# 2026-09-25 OVH2 107 (matomo) Upgrades

Several maintenance updates of Matomo and it's OS were done.

## Matomo upgrade from 5.1.1 to 5.14.0

Before updating Matomo, I took a snapshot of the LXC container in Promox. Afterwards,
I first upgraded the plugins from the Matomo admin UI. Then, Matomo warned that the DB
needed upgrading, so I ran `/var/www/html/matomo/console core:update` in the shell.
As the `QueuedTracking` was updated, I also applied the fixes [mentioned here](../explanation/services/matomo.md).

Following that, the Matomo upgrade was done - also from the Matomo UI. I had
to run `console core:update` multiple times until the UI actually loaded without any
warnings. That did solve everything, though, and tracking seems to work as expected.

## Debian 10.13 to 12.0

### Debian 10.13 to 11.11

Before updating Debian, I took a snapshot of the LXC container in Promox. I then followed
the upgrade instructions from [Debian](https://www.debian.org/releases/bookworm/amd64/release-notes/ch-upgrading.html).

1. Ensured everything as up-to date `apt update && apt full-upgrade` (0 packages needed updating)
2. Replaced `buster` to `bullseye` in `/etc/apt/sources.list`
3. Prepare and ensure now audit errors/held packages could cause issues:
    * `apt update`
    * `dpkg --audit`
4. I updated the system step by step:

    * `apt update`
    * `apt upgrade --without-new-pkgs`
      * Some packages were 404 for some reason. I re-ran with `apt upgrade --without-new-pkgs --fix-missing`
        to avoid that.
    * `apt full-upgrade` also complained about missing packages in the `bullseye-security` repo. As we're
      going to upgrade to the next Debian release anyways, I temporarily disable the security repo.
    * `apt full-upgrade`
      * When asked whether to automatically restart services during setup, I said yes.
      * `/etc/mysql/mariadb.cnf` was replaced during the update: No relevant settings were changed.
        Overrides from [90-off-configs.cnf](../../confs/matomo/mysql/mariadb.conf.d/90-off-configs.cnf)
        override those modified during the upgrade.
      * `/etc/nginx/sites-available/default`: The current version was kept, because it contains the matomo site
      * `/etc/sudoers`: Current version kept due to `NOPASSWD` modifications
      * `/etc/mysql/mariadb.conf.d/50-server.cnf` current version was kept
5. After the upgrade, [analytics](https://analytics.openfoodfacts.org/) came up with a `502 Bad Gateway` error.
   I had to update `/etc/nginx/sites-available/default` to use PHP 7.4 instead of 7.3:
   `fastcgi_pass unix:/run/php/php7.4-fpm.sock;`
   However, for some reason, `php7.4-fpm` wasn't actually installed any more (and `php7.3-fpm` had been removed),
   so I reinstalled it using `apt install php7.4-fpm`.
   Other necessary steps:

   * Copy PHP settings from `cp /etc/php/7.3/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/www.conf`
   * Use php.ini from repo:

     ```bash
     mv /etc/php/7.4/cli/php.ini /etc/php/7.4/cli/php.dist.ini
     mv /etc/php/7.4/fpm/php.ini /etc/php/7.4/fpm/php.dist.ini
     ln -s /opt/openfoodfacts-infrastructure/confs/matomo/php/7.4/cli/php.ini /etc/php/7.4/cli/php.ini
     ln -s /opt/openfoodfacts-infrastructure/confs/matomo/php/7.4/fpm/php.ini /etc/php/7.4/fpm/php.ini
     ```

   * Restart nginx and PHP `systemctl restart php7.4-fpm.service nginx.service`
   * Matomo starts, but I get greeted with a nice message:
     > The mysql driver is not currently installed
     So I installed it. `apt install php7.4-mysql && systemctl restart php7.4-fpm.service`

6. Matomo is up! However Matomo diagnostics showed some more missing (recommended) PHP modules:

   ```bash
   root@analytics:/var/www/html/matomo# ./console diagnostics:run
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(52): Notice - Trying to access array offset on value of type bool - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(53): Notice - Trying to access array offset on value of type bool - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(54): Notice - Trying to access array offset on value of type bool - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(58): Notice - Trying to access array offset on value of type null - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(59): Notice - Trying to access array offset on value of type null - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(59): Notice - Trying to access array offset on value of type null - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(60): Notice - Trying to access array offset on value of type null - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(61): Notice - Trying to access array offset on value of type null - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(62): Notice - Trying to access array offset on value of type null - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   WARNING   [2026-09-26 07:47:23] 10180  /var/www/html/matomo/plugins/DiagnosticsExtended/Diagnostic/OpcacheCheck.php(63): Notice - Trying to access array offset on value of type null - Matomo 5.14.0 - Please report this message in the Matomo forums: https://forum.matomo.org (please do a search first as it might have been reported already)
   File integrity: WARNING File integrity check failed and reported some errors. You should fix this issue and then refresh this page until it shows no error.
   
   Files were found in your Matomo, but we didn't expect them.
   --> Please delete these files to prevent errors. <--
   
   File to delete: CHANGELOG.md
   File to delete: CONTRIBUTING.md
   
   
   To delete all these files at once, you can run this command:
   rm "/var/www/html/matomo/CHANGELOG.md" "/var/www/html/matomo/CONTRIBUTING.md"
   
   
   GD &gt; 2.x + FreeType (graphics): WARNING GD &gt; 2.x + FreeType (graphics)
   The sparklines (small graphs) and image graphs (in the Matomo mobile app and email reports) will not work.
   Other extensions:
           - OK json
           - OK libxml
           - WARNING dom
   You should turn on the "dom" extension (e.g., install the "php-dom" and/or "php-xml" package).
           - WARNING SimpleXML
   You should enable the "SimpleXML" extension (e.g., install the "php-simplexml" and/or "php-xml" package).
           - OK openssl
   🧪 php.ini options:
           - OK allow_url_include is enabled
           - OK display_errors is enabled
           - WARNING expose_php should be disabled
   🧪 PHP version:
           - OK You are using the latest version of PHP 7.4
           - WARNING Your PHP version (7.4.33) does not receive security support by the PHP team anymore (since Monday, November 28, 2022). You should update to a newer version (unless the distributor of your PHP binary is backporting security patches).
   🧪 Database version:
           - WARNING There is a newer MariaDB patch version (10.5.29) available (you are using 10.5.23-MariaDB-0+deb11u1/10.5.23). You should update to it as soon as possible (unless the distributor of your MariaDB binary is backporting security patches).
           - WARNING Your MariaDB version (10.5.23) does not receive security support by the MariaDB team anymore (since Tuesday, June 24, 2025). You should update to a newer version (unless the distributor of your MariaDB binary is backporting security patches).
   🧪 PHP running as root: WARNING PHP seems to be running as root. Unless you are using Matomo inside a docker container you should check your setup.
   7 warnings detected
   Error: error or warning logs detected, exit 1
   root@analytics:/var/www/html/matomo# apt install php7.4-xml
   ```

7. 