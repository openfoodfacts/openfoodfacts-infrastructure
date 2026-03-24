# 2026-02-22 Moving stunnel to off1

While moving [redis to scaleway](./2026-02-26-moving-redis-to-scaleway.md),
I saw that stunnel is taking quite a lot of CPU on off2,
which is already really struggling.

As I will move redis and postgres, this share might augment.

So I decided to move stunnel to off1.

## Cloning and moving

I tried to move directly the 103 container to off2 using proxmox interface, but it failed.
I had tried to first replicate it to off1, but it also failed.

So I did a snapshot of the container (because it was mandatory),
cloned the container with a new id 105,
and moved it to off1 (while still shutdown).

Then I did edit the network to change the ipv4 to `10.1.0.105/24`,
and ipv6 to `fd28:7f08:b8fe:0::105/64` (that is I replaced `103` by `105` in both).

I then started the container.

Going inside it I was able to see my config was the expected one.

I changed the accept ip address to my new one for all entries in `/etc/stunnel/off.conf`,
and do a `systemctl restart stunnel@off.service`

## Testing connections

We have two currently active connections:
1. off-query (because it is in ipv6, we use stunnel from the reverse proxy)
2. scaleway-mongodb (migrated to scaleway)

### Testing Mongodb

I go on off1, restarted vm 102 temporarily (mongodb),
and in the mongodb container, i use:
```bash
mongo 10.1.0.105:27017/off
> db.products.count()
4365732
```
It works perfectly.

### Testing off-query

Now for off query, from the off2 reverse proxy,
I do:
```bash
curl 10.1.0.105:16001/health
#  {"status":"ok","info":{"postgres":{"status":"up"},"mongodb":{"status":"up"},"redis":{"status":"up"}}}a
```
There again it works.

## Switching to new stunnel

Now I can switch to the new stunnel.

Using grep, I can see it used in `./confs/off2-reverse-proxy/nginx/sites-enabled/query.openfoodfacts.org`, as expected.
But it's also used by off / obf / opff and opf.

### Switching stunnel in product opener instances

I'll do that for MongoDB address in off / obf / opff and opf first.

For each instance, I will:
* modify MongoDB url: `sudo -u off vim /srv/$HOSTNAME/lib/ProductOpener/Config2.pm`
  to change `$mongodb_host` to `"10.1.0.105"`
  and on off, to change `$query_url` to `"http://10.1.0.105:16001"`;

* then: 
  ```bash
  sudo systemctl stop apache2 && sudo systemctl start apache2
  [[ "$HOSTNAME" = off ]] && sudo systemctl stop apache2@priority && sudo systemctl start apache2@priority
  sudo systemctl restart cloud_vision_ocr@$HOSTNAME.service minion@$HOSTNAME.service redis_listener@$HOSTNAME.service
  ```

Each time to verify, I look at a facet and do a search on the corresponding website.

### Switching stunnel in the reverse proxy

As the service is not access often, I did the change in the [reverse same commit](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/cd7408cd834af1e1d90fba2a401a9b229a4c1345),
updated the reverse proxy `/opt/openfoodfacts-infrastructure`,
restarted nginx, and tested `https://query.openfoodfacts.org/health`.

## turning off the old stunnel

Now we can look at the log of the old stunnel, on off2 / container 103
to verify there is no more connections.

```bash
journalctl -xef -u -f stunnel@off.service
...
févr. 27 10:57:46 stunnel-client stunnel4[3530617]: 2026.02.27 10:57:46 LOG5[1261927]: Connection closed: 197 byte(s) sent to TLS, 246 byte(s) sent to socket
```
while it's already `10:59:31`

So we can safely shut it down.