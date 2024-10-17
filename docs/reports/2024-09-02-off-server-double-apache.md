# 2024-09-02 OFF server double apache

## Goal

We experience latency problems on Open Food Facts because the Apache instance is busy processing long requests (facets / searches / etc.).

We can't prioritize requests based on URL in Apache2 (or dedicate workers).

We will setup a second Apache instance which will only serve certain requests:

* Product read (api or not)
* root page for every country
* product writes (api or not)

The rest of the requests will be handled by the other apache2 server.

## Reflexion on how to setup the new apache2 instance

On debian, apache2 is managed by systemd. There is:
* a default `apache2.service` service definition, using /etc/apache2/ configuration directory
* and an `apache2@<instance>.service` definition which use /etc/apache2.%i/ configuration directory (where %i is the instance name)

Both use the apache2ctl script to start apache2.
So we can use APACHE_ARGUMENTS to add arguments to httpd daemon program,
and this can be used to add -D arguments to add variables.

Here we want to create a second apache2 instance where the only differences are:
* the port apache2 is listening on
* the log file names

For the log file names, we will modify startup_apache2.pl to use environment variable to get the log configuration file.

For ports, we need to modify ports.conf file to use a variable that we will give thanks to a -D option to apache2 with APACHE_ARGUMENTS variable.

To be more consistent, we will drop the `apache2.service` instance and use two new instances:
* apache2@main.service - for product read, root pages and product writes
* apache2@secondary.service - for the rest

## Doing it in Product-Opener

See https://github.com/openfoodfacts/openfoodfacts-server/pull/10766

## Installation / Migration

1. checkout the new release / code
2. symlink /srv/$SERVER_NAME/conf/systemd/apache2@.service to /etc/systemd/system/apache2@.service
2. enable the apache2@main.service apache2@secondary.service
2. start apache2@secondary.service 
2. and test it's working using `curl http://127.0.0.1:8005/ -H "Host: world.openfoodfacts.org"`
2. check nginx configuration is ok (`nginx -t`) and restart the service
3. check both apache2 are working:
   * `curl http://127.0.0.1/ -H "Host: world.openfoodfacts.org"`
   * `curl http://127.0.0.1/discover -H "Host: world.openfoodfacts.org"`
   and using your browser
2. stop apache2.service
2. start apach2@main.service
3. test it's working using curl commands above and using your browser
1. deactivate  apache2.service
1. unlink the /etc/systemd/system/apache2.service
1. unlink /srv/$SERVER_NAME/log.conf

Celebrate !

**FIXME:** modify doc explaining off installation
**FIXME:** add the deployment documentation