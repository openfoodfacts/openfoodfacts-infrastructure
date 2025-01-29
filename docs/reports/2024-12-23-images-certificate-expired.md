# 2024-12-23 SSL certificate on images.openfoodfacts.org expired

On the 23rd of December 2024, I (Raphaël) noticed that the SSL certificate on `images.openfoodfacts.org` had expired.

I checked the certificate on the server, and it looks like certbot was not configured on the server, and that the SSL certificate was copied manually (see https://openfoodfacts.github.io/openfoodfacts-infrastructure/reports/2024-09-24-kimsufi-stor-ks1-installation/#configure).

I deleted the certificate folder:

```bash
rm -rf /etc/letsencrypt/live/images.openfoodfacts.org/
```

change the nginx configuration to listen on port 80, and restarted the nginx service.

I then launched certbot to generate a new certificate.

```bash
certbot -d images.openfoodfacts.org
```