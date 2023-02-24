# NGINX Reverse proxy (OVH)

At OVH we have a lxc container dedicated to reverse proxy http/https applications.

## Network specific interface

It as a specific network configurations with two ethernet address:
* one internal, to communicate with other VMs
* one which is bridged on host network card, with ip fail over mechanism.

**Important**: only the public ip should have a gateway [^proxmox_multiple_gateway]


[^proxmox_multiple_gateway]: The default proxmox interface does not offer options to indicate which gateway should be the default gateway, and the public ip needs to have its gateway as the default one, and there is no trivial way to achieve this reliably and elegantly, thus the best solution is to have only one gateway. See also [ovh reverse proxy incident of 2022-02-18](./reports/2022-02-18-ovh-reverse-proxy-down.md)

## Configuring a new service

To make a new service, hosted on proxmox, available you needs to:

* have this service available on proxmox internal network
* in the DNS, CNAME you service name to `proxy1.openfoodfacts.org`
* write a configuration on nginx for this service
* eventually add https


### Steps to create Nginx configuration

we will imagine we configure **my-service.openfoodfacts.net**

You will have to be root to do that.

Login on container (101) and start a root bash.

Create the basic configuration file for your service in `/etc/nginx/conf.d` named `my-service.openfoodfacts.net.conf` on machine `222`, port `8888`.

**Important**: your file has to ends with `.conf` to be taken into account.

It's a good idea to first test it exists, using nc and curl:

```bash
nc -vz 10.1.0.222 8888
curl  http://10.1.0.222:8888
```

Create a config, say:

```nginx
server {

    listen 80;
    listen [::]:80;
    server_name  my-service.openfoodfacts.net;

    access_log  /var/log/nginx/my-service.off.net.log  main;
    error_log   /var/log/nginx/my-service.off.net.err;

    location / {
        proxy_pass http://10.1.0.222:8888$request_uri;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 90;
        client_max_body_size 512M;
    }

}
```

If you need more [nginx docs are here](https://nginx.org/en/docs/)

We test nginx configuration is ok (**Mandatory**)[^test-nginx]:

```bash
$ nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

if it's ok, we reload.
```bash
$ systemctl reload nginx
```

Next step is probably to setup https (putting something in http should be an exception, with good reason for that !)
Otherwise jump to [EtcKeeper](#etc-keeper)

[^test-nginx]: the nginx script will normally do the check before trying to restart nginx, but this way you are able to also see warnings.

### Adding https

Most of the time https certificates are managed on the nginx reverse proxy VM. Here is how to configure them to enable https.

We use certbot to manage certificates.

First prepare the service definition to answer on port 443 and 80. That is:

- change your current configuration to listen on 443:
  ```nginx
  {
    server {

    listen 443;
    listen [::]:443;
    server_name  my-service.openfoodfacts.net;
    …
  ```
- but after it, add a new bare section for port 80:
  ```nginx
  server {
    listen 80;
    listen [::]:80;
    server_name  my-service.openfoodfacts.net;
  }
  ```

We will first validate our config using `--test-cert` option (**WARNING** only skip this part if you really are used to certbot and nginx configuration, as after five tentatives, we won't be able to renew any certificates on the domain for one full week, and if you do too much error, the IP itself might be out of limit, see [letsencrypt Rate limits](https://letsencrypt.org/docs/rate-limits/))

```
$ certbot --test-cert -d my-service.openfoodfacts.net
…
Enter email address (used for urgent renewal and security notices) (Enter 'c' to
cancel): root@openfoodfacts.org
…
terms of service…
(A)gree/(C)ancel: A
…
share email…
(Y)es/(N)o: n

Obtaining a new certificate
Performing the following challenges:
http-01 challenge for my-service.openfoodfacts.net
Waiting for verification...
Cleaning up challenges
Deploying Certificate to VirtualHost /etc/nginx/conf.d/my-service.openfoodfacts.net.conf
```

**Note:** verify it's the right file which has been impacted ! If it's not you may have the option to restore the file with `git checkout wrong-touched-file` (but look before with `git status`)

Test it's working (apart from the security alert in your browser, because certificate is from an unknown issuer).

Then install the real certificate (you get the first section if you first did a test certificate):

```
$ certbot -d my-service.openfoodfacts.net
1: Attempt to reinstall this existing certificate
2: Renew & replace the cert (limit ~5 per 7 days)
Select … [enter] (press 'c' to cancel): 2
…
Enter email address (used for urgent renewal and security notices) (Enter 'c' to
cancel): root@openfoodfacts.org
…
terms of service…
(A)gree/(C)ancel: A
…
share email…
(Y)es/(N)o: n

Obtaining a new certificate
Performing the following challenges:
http-01 challenge for my-service.openfoodfacts.net
Waiting for verification...
Cleaning up challenges
Deploying Certificate to VirtualHost /etc/nginx/conf.d/my-service.openfoodfacts.net.conf
```

Test again if it's working

#### Multiple domains

If you're in the case where same configuration must serve multiple domains, like ui.my-site.openfoodfacts.net and api.my-site.openfoodfacts.net,
simply add all those domain to the certbot command with the `-d` parameters.

For example:

```bash
certbot -d ui.my-site.openfoodfacts.net -d api.my-site.openfoodfacts.net -d my-site.openfoodfacts.net
```

If a certificate already exists for a domain, certbot will propose to extend it with the other domains.

### Etc Keeper

We use [etckeeper](./linux-server.md#etckeeper)
Do not forget to commit your changes:

```bash
etckeeper commit -m "Configured my-service.openfoodfacts.net"
```

Now we are done 🎉