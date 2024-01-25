# Matomo

[Matomo](https://matomo.org/) is the web analytics platform.

Available at: https://analytics.openfoodfacts.org/

You must have a user account to access it (hopefully !). Ask for an admin to create you an account if you need it (Beware, there are personal information in the sense of GDPR like ip addresses).
Ask for it to *contact* email.

## Main running services

* nginx is used as a HTTP frontend
* php7.3-fpm run the matomo software
* mariadb is the main database for matomo, some configurations are made for performance (see `/etc/mysql/mariadb.conf.d/90-off-configs.cnf` )
* redis is used to fast track  matomo requests (see [Matomo setup for performance, below](#matomo-setup-for-performance))
* Two systemd timer takes care of putting tracking from redis to mariadb and to consolidate archive reports (see [Matomo setup for performance, below](#matomo-setup-for-performance))
* prometheus exporters are installed for nginx and mysql (see [Prometheus exporters, below](#prometheus-exporters))

Most of those systemd services should email on failures.

Important configuration files are linked to this git repository (see [using git, below](#using-git))


## Site setup

* goto manage / websites and add a website

### GDPR

To be GDPR compliant (and user friendly) [^gdpr_ref]:

- in your Matomo Tag, you can check the option « Disable cookies » which will disable all first party tracking cookies for Matomo. [^disable_cookies]
- To ensure that you do not store the visitor IP, which is Personally Identifiable Information (PII), please go to Administration > Privacy > Anonimyze data, to enable IP anonymization, and check you have 2 bytes or 3 bytes masked from the IP address. [^ip_anon]

[^gdpr_ref]: https://fr.matomo.org/blog/2018/04/how-to-make-matomo-gdpr-compliant-in-12-steps/

[^disable_cookies]: https://fr.matomo.org/faq/general/faq_157/

[^ip_anon]: https://matomo.org/faq/general/configure-privacy-settings-in-matomo/#step-1-automatically-anonymize-visitor-ips

### In productopener

We use the `$google_analytics` variable in config to add the javascript snippet for Matomo.

## Matomo install

See also [Install log](./reports/2021-02-22-matomo-install.md) and [2023-12-11 Matomo down](./reports/2023-12-11-matomo-down.md)

### using git

We use git to track some important configurations files in this repository.

The repository is checked out in /opt/openfoodfacts-infrastructure and specific `/etc` configurations files are symlinked there (see `confs/matomo`).

### Matomo setup for performance

We setup matomo for performance (our websites requires it) with two main points:

* it does not process archives on incoming requests but instead on a cron job (see `confs/matomo/cront.d/matomo-archive`).
  See also [official doc](https://matomo.org/faq/on-premise/how-to-set-up-auto-archiving-of-your-reports/).
* on incoming update request (on a tracked website being visited), it does not immediately updates the database but goes in redis instead,
  then a cron job process redis entries every minute (see `confs/matomo/cront.d/matomo-tracking`).
  See also [official doc](https://matomo.org/faq/on-premise/how-to-configure-matomo-to-handle-unexpected-peak-in-traffic/)
* `MariaDB` has been tuned a bit toward performance (using more memory) see `/etc/mysql/mariadb.conf.d/90-off-configs.cnf` (linked to this repository)
  * we also tried to avoid "2006 MySQL server has gone away" following https://matomo.org/faq/troubleshooting/faq_183/

Both cronjob logs to `/var/log/matomo`.

See also [2023-12-11 Matomo down](./reports/2023-12-11-matomo-down.md)

### Prometheus exporters

Nginx prometheus exporter is installed and needs the stub_status site, which exposes nginx metrics.

Mysql server prometheus exporter is installed (for MariaDB), its `/etc/default` configuration file sets the connection string.
The corresponding mysql user had to be manually created (instrutions in the config file).

### Updating the Matomo version

Just use the web administration to update the software.

### Setup robots.txt to avoid search engine indexing

Setup `/var/www/html/matomo/robots.txt` as is:
```
User-agent: *
Disallow: /
```


## How to

### How to test a command in php cli

For example I wanted to determine if we support async in CliMulti (used by `core::archive`).

The important thing is to go in the right directory and include the `console` script.

```bash
cd /var/www/html/matomo/
php -a

php > include "console";
...
php > use Piwik\CliMulti\Process;
php > echo Piwik\CliMulti\Process::isSupported();
1
php > use Piwik\CliMulti;
php > $p = new Piwik\CliMulti();
php > echo $p->supportsAsync();
1
```
