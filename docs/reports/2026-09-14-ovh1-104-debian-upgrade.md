# 2026-09-14 OVH1 104 (wiki) Debian Upgrade

The wiki was still running a Debian Bullseye 11.11. I upgraded the
OS to Debian Bookworm 12.15, which is still in support today.

## Upgrade from 10 to 11

1. Commended all sources in I `/etc/apt/sources.list` and created
   `/etc/apt/sources.list.d/debian.sources` in deb822 format for
   easier updates in the future, and changed the code name from buster to bullseye
   in `/etc/apt/sources.list.d/extrepo_sury.sources`

2. I updated the system step by step:

    * `apt update`
    * `apt upgrade --without-new-pkgs`
    * `apt full-upgrade`

3. During the installation process several questions arose:
   * changes in `/etc/sudoers`: get maintainer file,
     but afterward, restore the %sudo line with `%sudo ALL=(ALL) NOPASSWD: ALL`

4. The `apt full-upgrade` did exit with errors the first time
   ```bash
   E: Sub-process /usr/bin/dpkg returned an error code (1)
   ```

   Re-running it again made the issue visible: Mixed PHP setup with potentially bad/outdated configs:
   ```bash
   # apt full-upgrade
   Reading package lists... Done
   Building dependency tree... Done
   Reading state information... Done
   Calculating upgrade... Done
   The following packages were automatically installed and are no longer required:
     cpp-10 libabsl20200923 libaom0 libatomic1 libavif9 libbpf0 libcbor0 libdav1d4 libdns-export1110 libgav1-0 libgs9-common libicu67 libilmbase25 libisc-export1105 libllvm11 libmpdec3 libnetpbm10 libopenexr25 libpcrecpp0v5 libperl5.32 libprocps8 libpython3.9-minimal libpython3.9-stdlib libtiff5 libvulkan1 libwayland-client0 libwebp6 libwmf-0.2-7 libwmf0.2-7 libx265-192
     mariadb-server-10.5 mesa-vulkan-drivers perl-modules-5.32 php-symfony-polyfill-php80 php7.4-curl php7.4-mysql php7.4-xml python3.9 python3.9-minimal telnet ttf-dejavu-core
   Use 'sudo apt autoremove' to remove them.
   0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
   4 not fully installed or removed.
   After this operation, 0 B of additional disk space will be used.
   Do you want to continue? [Y/n] y
   Setting up php7.4-fpm (1:7.4.33-30+0~20260703.120+debian12~1.gbp1cce3b) ...
   NOTICE: Not enabling PHP 7.4 FPM by default.
   NOTICE: To enable PHP 7.4 FPM in Apache2 do:
   NOTICE: a2enmod proxy_fcgi setenvif
   NOTICE: a2enconf php7.4-fpm
   NOTICE: You are seeing this message because you have apache2 package installed.
   Job for php7.4-fpm.service failed because the control process exited with error code.
   See "systemctl status php7.4-fpm.service" and "journalctl -xeu php7.4-fpm.service" for details.
   invoke-rc.d: initscript php7.4-fpm, action "restart" failed.
   ● php7.4-fpm.service - The PHP 7.4 FastCGI Process Manager
        Loaded: loaded (/lib/systemd/system/php7.4-fpm.service; enabled; preset: enabled)
        Active: activating (auto-restart) (Result: exit-code) since Mon 2026-09-14 20:08:53 UTC; 8ms ago
          Docs: man:php-fpm7.4(8)
       Process: 13320 ExecStart=/usr/sbin/php-fpm7.4 --nodaemonize --fpm-config /etc/php/7.4/fpm/php-fpm.conf (code=exited, status=226/NAMESPACE)
       Process: 13321 ExecStopPost=/usr/lib/php/php-fpm-socket-helper remove /run/php/php-fpm.sock /etc/php/7.4/fpm/pool.d/www.conf 74 (code=exited, status=226/NAMESPACE)
      Main PID: 13320 (code=exited, status=226/NAMESPACE)
   dpkg: error processing package php7.4-fpm (--configure):
    installed php7.4-fpm package post-installation script subprocess returned error exit status 1
   Setting up php8.3-fpm (8.3.33-1+0~20260730.86+debian12~1.gbp9ff550) ...
   NOTICE: Not enabling PHP 8.3 FPM by default.
   NOTICE: To enable PHP 8.3 FPM in Apache2 do:
   NOTICE: a2enmod proxy_fcgi setenvif
   NOTICE: a2enconf php8.3-fpm
   NOTICE: You are seeing this message because you have apache2 package installed.
   Job for php8.3-fpm.service failed because the control process exited with error code.
   See "systemctl status php8.3-fpm.service" and "journalctl -xeu php8.3-fpm.service" for details.
   invoke-rc.d: initscript php8.3-fpm, action "restart" failed.
   ● php8.3-fpm.service - The PHP 8.3 FastCGI Process Manager
        Loaded: loaded (/lib/systemd/system/php8.3-fpm.service; enabled; preset: enabled)
        Active: activating (auto-restart) (Result: exit-code) since Mon 2026-09-14 20:08:54 UTC; 9ms ago
          Docs: man:php-fpm8.3(8)
       Process: 14625 ExecStart=/usr/sbin/php-fpm8.3 --nodaemonize --fpm-config /etc/php/8.3/fpm/php-fpm.conf (code=exited, status=226/NAMESPACE)
       Process: 14626 ExecStopPost=/usr/lib/php/php-fpm-socket-helper remove /run/php/php-fpm.sock /etc/php/8.3/fpm/pool.d/www.conf 83 (code=exited, status=226/NAMESPACE)
      Main PID: 14625 (code=exited, status=226/NAMESPACE)
   
   Sep 14 20:08:54 wiki systemd[1]: php8.3-fpm.service: Failed with result 'exit-code'.
   Sep 14 20:08:54 wiki systemd[1]: Failed to start php8.3-fpm.service - The PHP 8.3 FastCGI Process Manager.
   dpkg: error processing package php8.3-fpm (--configure):
    installed php8.3-fpm package post-installation script subprocess returned error exit status 1
   Setting up php8.4-fpm (8.4.25-1+0~20260828.55+debian12~1.gbp259445) ...
   NOTICE: Not enabling PHP 8.4 FPM by default.
   NOTICE: To enable PHP 8.4 FPM in Apache2 do:
   NOTICE: a2enmod proxy_fcgi setenvif
   NOTICE: a2enconf php8.4-fpm
   NOTICE: You are seeing this message because you have apache2 package installed.
   Job for php8.4-fpm.service failed because the control process exited with error code.
   See "systemctl status php8.4-fpm.service" and "journalctl -xeu php8.4-fpm.service" for details.
   invoke-rc.d: initscript php8.4-fpm, action "start" failed.
   ● php8.4-fpm.service - The PHP 8.4 FastCGI Process Manager
        Loaded: loaded (/lib/systemd/system/php8.4-fpm.service; enabled; preset: enabled)
        Active: activating (auto-restart) (Result: exit-code) since Mon 2026-09-14 20:08:55 UTC; 9ms ago
          Docs: man:php-fpm8.4(8)
       Process: 15837 ExecStart=/usr/sbin/php-fpm8.4 --nodaemonize --fpm-config /etc/php/8.4/fpm/php-fpm.conf (code=exited, status=226/NAMESPACE)
       Process: 15838 ExecStopPost=/usr/lib/php/php-fpm-socket-helper remove /run/php/php-fpm.sock /etc/php/8.4/fpm/pool.d/www.conf 84 (code=exited, status=226/NAMESPACE)
      Main PID: 15837 (code=exited, status=226/NAMESPACE)
   
   Sep 14 20:08:55 wiki systemd[1]: php8.4-fpm.service: Failed with result 'exit-code'.
   Sep 14 20:08:55 wiki systemd[1]: Failed to start php8.4-fpm.service - The PHP 8.4 FastCGI Process Manager.
   dpkg: error processing package php8.4-fpm (--configure):
    installed php8.4-fpm package post-installation script subprocess returned error exit status 1
   dpkg: dependency problems prevent configuration of php-fpm:
    php-fpm depends on php8.4-fpm; however:
     Package php8.4-fpm is not configured yet.
   
   dpkg: error processing package php-fpm (--configure):
    dependency problems - leaving unconfigured
   Errors were encountered while processing:
    php7.4-fpm
    php8.3-fpm
    php8.4-fpm
    php-fpm
   E: Sub-process /usr/bin/dpkg returned an error code (1)
   ```
   `ls /etc/apache2/conf-enabled/*php*` showed `php8.3-fpm.conf` being present and `apt list --installed | grep php` showed that `php7.4-fpm`,
   `php8.3-fpm`, `php8.4-fpm`, and `php8.5-fpm` were installed with several modules each.
   I uninstalled all unnecessary PHP versions with `apt remove "^php(7\.4|8\.5).*"`,
   then got the php8.3 modules that were installed previously:
   ```bash
   # apt list --installed | grep php8.3
   
   WARNING: apt does not have a stable CLI interface. Use with caution in scripts.
   
   php8.3-cli/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-common/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-curl/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-fpm/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-gd/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-imagick/bookworm,now 3.8.1-1+0~20260621.55+debian12~1.gbpde1d95 amd64 [installed]
   php8.3-imap/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-intl/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-mbstring/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-mysql/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-opcache/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-readline/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-xml/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   php8.3-zip/bookworm,now 8.3.33-1+0~20260730.86+debian12~1.gbp9ff550 amd64 [installed]
   ```
   And removed PHP 8.3, too, using `apt remove "^php8\.3.*"`.

   The full-upgrade still reported failing php8.4-fpm startup:
   ```bash
   # apt full-upgrade
   Reading package lists... Done
   Building dependency tree... Done
   Reading state information... Done
   Calculating upgrade... Done
   The following packages were automatically installed and are no longer required:
     cpp-10 libabsl20200923 libabsl20220623 libaom0 libatomic1 libavif15 libavif9 libbpf0 libc-client2007e libcbor0 libdav1d4 libdns-export1110 libgav1-0 libgav1-1 libgd3 libgs9-common libicu67 libilmbase25 libimagequant0 libisc-export1105 libllvm11 libmpdec3 libnetpbm10 libopenexr25 libpcrecpp0v5 libperl5.32 libprocps8 libpython3.9-minimal libpython3.9-stdlib librav1e0
     libsvtav1enc1 libtiff5 libvulkan1 libwayland-client0 libwebp6 libwmf-0.2-7 libwmf0.2-7 libx265-192 libyuv0 mariadb-server-10.5 mesa-vulkan-drivers mlock perl-modules-5.32 php-symfony-polyfill-php80 python3.9 python3.9-minimal telnet ttf-dejavu-core
   Use 'sudo apt autoremove' to remove them.
   0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
   2 not fully installed or removed.
   After this operation, 0 B of additional disk space will be used.
   Do you want to continue? [Y/n] y
   Setting up php8.4-fpm (8.4.25-1+0~20260828.55+debian12~1.gbp259445) ...
   NOTICE: Not enabling PHP 8.4 FPM by default.
   NOTICE: To enable PHP 8.4 FPM in Apache2 do:
   NOTICE: a2enmod proxy_fcgi setenvif
   NOTICE: a2enconf php8.4-fpm
   NOTICE: You are seeing this message because you have apache2 package installed.
   Job for php8.4-fpm.service failed because the control process exited with error code.
   See "systemctl status php8.4-fpm.service" and "journalctl -xeu php8.4-fpm.service" for details.
   invoke-rc.d: initscript php8.4-fpm, action "start" failed.
   ● php8.4-fpm.service - The PHP 8.4 FastCGI Process Manager
        Loaded: loaded (/lib/systemd/system/php8.4-fpm.service; enabled; preset: enabled)
        Active: activating (auto-restart) (Result: exit-code) since Mon 2026-09-14 20:29:51 UTC; 8ms ago
          Docs: man:php-fpm8.4(8)
       Process: 34808 ExecStart=/usr/sbin/php-fpm8.4 --nodaemonize --fpm-config /etc/php/8.4/fpm/php-fpm.conf (code=exited, status=226/NAMESPACE)
       Process: 34809 ExecStopPost=/usr/lib/php/php-fpm-socket-helper remove /run/php/php-fpm.sock /etc/php/8.4/fpm/pool.d/www.conf 84 (code=exited, status=226/NAMESPACE)
      Main PID: 34808 (code=exited, status=226/NAMESPACE)
   
   Sep 14 20:29:51 wiki systemd[1]: php8.4-fpm.service: Failed with result 'exit-code'.
   Sep 14 20:29:51 wiki systemd[1]: Failed to start php8.4-fpm.service - The PHP 8.4 FastCGI Process Manager.
   dpkg: error processing package php8.4-fpm (--configure):
    installed php8.4-fpm package post-installation script subprocess returned error exit status 1
   dpkg: dependency problems prevent configuration of php-fpm:
    php-fpm depends on php8.4-fpm; however:
     Package php8.4-fpm is not configured yet.
   
   dpkg: error processing package php-fpm (--configure):
    dependency problems - leaving unconfigured
   Errors were encountered while processing:
    php8.4-fpm
    php-fpm
   E: Sub-process /usr/bin/dpkg returned an error code (1)
   ```
   Nevertheless, I enabled PHP 8.4 for apache2, just to be sure: `a2enmod proxy_fcgi setenvif && a2enconf php8.4-fpm && systemctl reload apache2 && systemctl restart apache2`
   But that didn't work. Tailing `/var/log/apache2/off.wiki.en.error.log` shows that either the PHP config is wrong, or that permissions needed to be updated:
   ```
   [Mon Sep 14 20:31:12.921556 2026] [proxy:error] [pid 28959:tid 28998] (2)No such file or directory: AH02454: FCGI: attempt to connect to Unix domain socket /var/run/php/php8.3-fpm.sock (localhost:8000) failed
   ```

   I decided to uninstall and reinstall PHP 8.4 and then copy the 8.3 configs to 8.4:
   ```bash
   apt remove php-fpm php8.4-fpm
   apt install php-fpm
   a2enmod proxy_fcgi setenvif && a2enconf php8.4-fpm && systemctl reload apache2 && systemctl restart apache2
   # cp 8.3/fpm/pool.d/www.conf 8.4/fpm/pool.d/
   # cp 8.3/fpm/php.ini 8.4/fpm/
   # cp 8.3/fpm/php-fpm.conf 8.4/fpm/
   ```
   Finally, the log showed a more useful error message:
   ```bash
   # journalctl -xeu php8.4-fpm.service
   Sep 14 20:56:32 wiki (t-helper)[6942]: php8.4-fpm.service: Failed to set up mount namespacing: /run/systemd/unit-root/proc: Permission denied
   Sep 14 20:56:32 wiki (t-helper)[6942]: php8.4-fpm.service: Failed at step NAMESPACE spawning /usr/lib/php/php-fpm-socket-helper: Permission denied
   ```
   That means we need to enable nesting, as already done for other containers: [proxmox, systemd needs nesting capability](../explanation/proxmox.md#systemd-needs-nesting-capability)
   `feature: nested=1` was added to `/etc/pve/lxc/104.conf` on ovh1, and the container was restarted.
   After that, php-fpm finally started.

5. For some reason, the PHP package configs at `/etc/php/8.4/fpm/` weren't created correctly, so I additionally purged PHP 8.4, and reinstalled it:
   ```bash
   # apt purge "^php(7\.4|8\.3|8\.5).*"
   # apt purge php8.4-cli php8.4-common php8.4-curl php8.4-fpm php8.4-gd php8.4-imagick php8.4-imap php8.4-intl php8.4-mbstring php8.4-mysql php8.4-opcache php8.4-readline php8.4-xml php8.4-zip
   # apt install --reinstall php php-intl php-mbstring php-apcu php-curl php-mysql php-fpm
   # a2enmod proxy_fcgi setenvif && a2enconf php8.4-fpm && systemctl reload apache2 && systemctl restart apache2
   # apt install php8.4-common php8.4-curl php8.4-gd php8.4-imagick php8.4-imap php8.4-intl php8.4-mbstring php8.4-mysql php8.4-opcache php8.4-readline php8.4-xml php8.4-zip php8.4-xml php8.4-xml php8.4-mbstring php8.4-ctype php8.4-iconv php8.4-fileinfo php8.4-apcu php8.4-curl
   ```

6. Finally, I noticed that apache2 was still trying to use `/var/run/php/php8.3-fpm.sock` instead of `/var/run/php/php8.4-fpm.sock`. It had to be changed in `/etc/apache2/sites-enabled/wiki.openfoodfacts.org.conf`.

After a final restart of the apache2 service, the wiki was running fine.
