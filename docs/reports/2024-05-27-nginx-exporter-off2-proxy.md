# Nginx exporter on off2 proxy and off

## On off2 reverse proxy


### Expose nginx stats

For nginx exporter we need to expose /stub_status on port 8080 (see [doc](https://github.com/nginxinc/nginx-prometheus-exporter)) https://nginx.org/en/docs/http/ngx_http_stub_status_module.html#stub_status

I created the `stub_status` conf for that (linked from this repository). I limited to 127.0.0.1, it should be internal.

Test it: `curl http://127.0.0.1:8080`

### Install Prometheus nginx exporter

Now install the exporter:
`sudo apt install prometheus-nginx-exporter`

As we are on a public interface, we don't want to expose the exporter widely, so we restrict it to 127.0.0.1

For that we do `systemctl edit prometheus-nginx-exporter` to add:
```conf
[Service]
# ONLY listen on 127.0.0.1 for security reasons
Environment="LISTEN_ADDRESS=127.0.0.1:9113"
```
And moved it to versioned space:
```bash
mv /etc/systemd/system/prometheus-nginx-exporter.service.d /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/ && \
ln -s /opt/openfoodfacts-infrastructure/confs/off2-reverse-proxy/systemd/system/prometheus-nginx-exporter.service.d /etc/systemd/system/
```

Reload: `systemctl daemon-reload && systemctl restart prometheus-nginx-exporter`

Check exporter status: `systemctl status prometheus-nginx-exporter`

Test it locally:
```bash
curl http://127.0.0.1:9113/metrics
```

Test it's not available from the public interface:
```bash
nc -vz 213.36.253.214 9113
nc: connect to 213.36.253.214 port 9113 (tcp) failed: Connection refused
```

Tested it from ovh2, it does not work but from ovh1 it works !

### Expose the metrics

Edit the `/etc/nginx/sites-enabled/free-exporters.openfoodfacts.org`
to add the right entry to the map directive:

```conf
# map from service to exporter
map $uri $exporter {
    ...
    # nginx on this proxy
    "/proxy/nginx/metrics" 127.0.0.1:9113;
    ...
```

Restart nginx and test it:
```
curl -u prometheus:**password-here**  https://free-exporters.openfoodfacts.org/proxy/nginx/metrics
```

## On off

### Expose nginx stats

I created the `stub_status` conf for that in `/srv/off/conf/nginx/sites-available/stub_status`
```conf
# This enables prometheus exporter to get data from nginx
server {
        listen 127.0.0.1:8080;
        stub_status on;
}
```
linked it:
`ln -s /srv/off/conf/nginx/sites-available/stub_status /etc/nginx/sites-enabled/`

Restart nginx and test it: `curl http://10.1.0.107:8080`

### Install Prometheus nginx exporter

Install the exporter:
`sudo apt install prometheus-nginx-exporter`

We are on a container without public interface so it's ok to expose the exporter.

Check exporter status: `systemctl status prometheus-nginx-exporter`

Test it locally:
```bash
curl http://127.0.0.1:9113/metrics
```

And on the reverse proxy:
```bash
curl http://10.1.0.113:9113/metrics
```

## Apache exporter

```bash
sudo apt install prometheus-apache-exporter
# get conf in git
sudo -u off mkdir conf/etc-default
sudo mv /etc/default/prometheus-apache-exporter /srv/off/conf/etc-default/
sudo ln -s /srv/off/conf/etc-default/prometheus-apache-exporter /etc/default/
sudo chown off:off /srv/off/conf/etc-default/prometheus-apache-exporter
```

Our apache is not exposing on a specific port 8004, so we need to edit the config file.

We edit `/etc/default/prometheus-apache-exporter`

```conf
# Set the command-line arguments to pass to the server.
ARGS='-scrape_uri http://127.0.0.1:8004/server-status/?auto'
```

restart: `sudo systemctl restart prometheus-apache-exporter`
verify:
`sudo systemctl status prometheus-apache-exporter`


Test:
```bash
curl http://10.1.0.113:9117/metrics
```

### Expose the metrics

As before by editing the map directive in `/etc/nginx/sites-enabled/free-exporters.openfoodfacts.org`

 test it:
```
curl -u prometheus:**password-here**  https://free-exporters.openfoodfacts.org/off/nginx/metrics
curl -u prometheus:**password-here**  https://free-exporters.openfoodfacts.org/off/apache/metrics
```

## Add the exporter to the monitoring stack

Edit `prometheus/config.yml` to add the two services path to free-exporters section.
(see [commit 811aaa36c](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/811aaa36c94b70e2b64e8fd3814b740023cf0d0b) and [commit e3ee4109e](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/e3ee4109eedfb391976a8784d3a919d8824f45bb))

The nginx dashboards works immediately.

I had to edit the apache dashboard as it was expecting a host:port pattern, which is not the case here,
I now only use instance name directly. (see [commit 08972b0](https://github.com/openfoodfacts/openfoodfacts-monitoring/commit/08972b0d0e97cb3e2f8813769ce56c961ce4e7df))