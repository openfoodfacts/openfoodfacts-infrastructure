# Matomo

[Matomo](https://matomo.org/) is the web analytics platform.

Available at: https://analytics.openfoodfacts.org/

You must have a user account to access it (hopefully !). Ask for an admin to create you an account if you need it (Beware, there are personal information in the sense of GDPR like ip addresses).
Ask for it to *contact* email.

## Main running services

* nginx is used as a HTTP frontend
* php7.3-fpm run the matomo software
* mariadb is the main database for matomo
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
* `MariaDB` has been tuned a bit toward performance (using more memory)

Both cronjob logs to `/var/log/matomo`.

See also [2023-12-11 Matomo down](./reports/2023-12-11-matomo-down.md)

### Prometheus exporters

Nginx prometheus exporter is installed and needs the stub_status site, which exposes nginx metrics.

Mysql server prometheus exporter is installed (for MariaDB), its `/etc/default` configuration file sets the connection string.
The corresponding mysql user had to be manually created (instrutions in the config file).