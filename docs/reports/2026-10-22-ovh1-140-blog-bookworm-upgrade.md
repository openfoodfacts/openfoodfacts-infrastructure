# 2026-10-22 OVH1 140 (blog) Debian Upgrade

The blog was still running Debian Bullseye 11.11, which is out of support.
I upgraded the OS to Debian Bookworm 12.15, and cleaned up PHP so that only PHP 8.4 remains.

## Context: PHP2Shell (CVE-2026-109618, CVE-2026-109619)

On 2026-10-20, PHP announced two critical unauthenticated remote code execution vulnerabilities,
fixed on 2026-10-21 in PHP 8.5.12, 8.4.27, 8.3.36 and 8.2.35
(see [PHP announcement](https://www.php.net/index.php#2026-10-21-5)).
PHP 8.1 and older do not get official fixes.

As a first mitigation (it only blocks some of the attack paths),
`session.upload_progress` was disabled on all our PHP containers
(ovh2 107 matomo, ovh1 104 wiki, ovh1 140 blog, ovh1 130 contents):

```bash
for d in /etc/php/*/fpm/conf.d /etc/php/*/cli/conf.d; do echo 'session.upload_progress.enabled = 0' > "$d/99-off-disable-upload-progress.ini"; done
systemctl restart 'php*-fpm.service'
# verify
for bin in /usr/sbin/php-fpm[0-9]* /usr/bin/php[0-9]*; do echo "$bin: $($bin -i 2>/dev/null | grep 'session.upload_progress.enabled')"; done
```

Then php-fpm was stopped on the affected containers until they were patched.

On the blog, PHP packages had not been updated since January 2026,
because the Sury repository signing key had expired (`EXPKEYSIG B188E2B695BD4743`)
and apt silently ignored the repository.

On 2026-10-21, Alex replaced the extrepo configuration by `/etc/apt/sources.list.d/extrepo_sury.list`
using the official Sury keyring (`/usr/share/keyrings/debsuryorg-archive-keyring.gpg`),
and upgraded PHP 8.4 to the patched 8.4.27 (bullseye build).
The upgrade ended with dpkg errors because php-fpm failed to start;
Alex fixed it by adding `lxc.cap.drop: "sys_rawio audit_read"` to `/etc/pve/lxc/140.conf` on ovh1,
and restarted the container. PHP-FPM was left stopped, waiting for the bookworm upgrade.

## Preparation

On ovh1:

```bash
pct snapshot 140 before_bookworm_20261022
```

`features: nesting=1` was already set on the container
(see [systemd needs nesting capability](../explanation/proxmox.md#systemd-needs-nesting-capability)).

In the container, I saved the state and backups:

```bash
dpkg -l 'php*' | awk '/^ii/{print $2}' > /root/php-packages-before.txt
mysqldump --all-databases --single-transaction > /root/all-db-before-bookworm.sql
tar czf /root/etc-before-bookworm.tgz /etc
```

## PHP cleanup (still on bullseye)

Apache was using `fpm-generic.conf` (socket `/run/php/php-fpm.sock`)
and the `php-fpm` alternative pointed to PHP 8.4.
PHP 7.4 and 8.5 (cli only) were also installed.

Having several PHP versions installed caused trouble during the [wiki upgrade](./2026-09-14-ovh1-104-debian-upgrade.md),
so I removed everything but PHP 8.4:

```bash
# make sure 8.4 packages are not removed by autoremove once the metapackages are gone
apt-mark manual $(dpkg -l 'php8.4*' 'php-common' | awk '/^ii/{print $2}')
apt purge '^php7\.4.*' '^php8\.5.*'
# generic metapackages (php-cli, php-fpm…) follow Sury's default version (8.5),
# they would bring back PHP 8.5 after the upgrade
apt purge php-cli php-curl php-fpm php-gd php-json php-mbstring php-mysql php-xml php-zip
```

## Upgrade to bookworm

1. Commented all lines in `/etc/apt/sources.list` and created `/etc/apt/sources.list.d/debian.sources`:

   ```
   Types: deb
   URIs: https://deb.debian.org/debian
   Suites: bookworm bookworm-updates
   Components: main contrib
   Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

   Types: deb
   URIs: https://security.debian.org/debian-security
   Suites: bookworm-security
   Components: main contrib
   Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
   ```

2. Changed `bullseye` to `bookworm` in `/etc/apt/sources.list.d/extrepo_sury.list`.

3. Upgraded the system step by step, in a `screen` session on ovh1:

   * `apt update`
   * `apt upgrade --without-new-pkgs`
   * `apt full-upgrade`

   For modified configuration files, I kept the local versions
   (`/etc/crontab` with its custom times, `/etc/apache2/sites-available/000-default.conf`
   which has `AllowOverride all` needed by WordPress).

   Everything went fine, without errors. MariaDB was upgraded from 10.5 to 10.11
   (`mariadb-upgrade` was run automatically).

4. Restarted the container: `pct reboot 140`

## Fixing Apache to PHP-FPM connection

After the reboot, the blog returned `503 Service Unavailable`.
`/run/php/php-fpm.sock` (used by `fpm-generic.conf`) did not exist anymore:
`/run` is cleared on reboot and the generic socket link was not recreated.

As there is now only one PHP version, I configured Apache to use the PHP 8.4 socket directly:

```bash
a2disconf fpm-generic
a2enmod proxy_fcgi setenvif
a2enconf php8.4-fpm
apachectl configtest && systemctl reload apache2
```

After that, the blog was working again.

## Result

* Debian 12.15
* PHP 8.4.27 (Sury), only PHP version installed
* MariaDB 10.11.19
* Apache 2.4.68

## Remaining tasks

* remove the snapshot `before_bookworm_20261022` after a few days
* the staging container (141) is an outdated bullseye clone, it should be re-created from 140
* the contents container (130) is still on bullseye with PHP 7.4 only, and needs the same upgrade
