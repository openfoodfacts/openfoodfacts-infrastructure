# How to copy nginx certificates

Sometimes, as you move a nginx proxy for a server to another,
it is better to have it immediately available,
and for that we have to copy certificates along with certbot configs
to the new server.

Here is a how you can do it (with [an example for openpetfoodfacts.org](../reports/2026-03-12-moving-opff-to-scaleway.md#setting-up-the-reverse-proxy)):

On the current server:
```bash
# change that to your site config
CONF=/etc/nginx/sites-enabled/openpetfoodfacts.org
DOM=$(sed -nr  "s|.*letsencrypt/live/(.*)/privkey.*|\1|p" $CONF)
# read if it looks good before continuing
echo "COPYING CERTS FOR $DOM in $DOM.tar.gz"

# important: no -h as we want to keep symlinks as is
sudo tar -cvzf $DOM.tar.gz \
    /etc/letsencrypt/archive/${DOM} \
    /etc/letsencrypt/renewal/${DOM}.conf \
    /etc/letsencrypt/live/${DOM}

# eventual owner change to help for transfer
sudo chmod go-rw $DOM.tar.gz
sudo chown alex:alex $DOM.tar.gz
```

Transfer the archive from one server to another (eg. using scp)

On the new server:
```bash
cd /
tar xzf /home/alex/openpetfoodfacts.org.tar.gz
# verify
ls -l /etc/letsencrypt/*/openpetfoodfacts.org /etc/letsencrypt/renewal/openpetfoodfacts.org.conf
```

Remember to remove copies of the file (possibly using `shred -u`)