# 2024-02-20 Installing a prometheus exporter on mongodb container

We have a problem of number of connections with mongodb.

It might be due to jobs launched by Raphaël, but I want to monitor it.

I am using:
```bash
while true; do data=$(mongosh --quiet --eval "db.serverStatus().connections.current"); echo $(date +"%Y-%m-%d-%H-%M")";"$data |tee -a /var/log/mongodb/alex-mongo-conn.log;sleep 300; done
```
but it might be a good occasion to setup a prometheus exporter to do the job.


## installing mongodb exporter

In mongodb container:
```bash
sudo apt install prometheus-mongodb-exporter
```

`dpkg-query -L prometheus-mongodb-exporter` helps me find config files.

I see in systemd service file a link to https://github.com/dcu/mongodb_exporter

`/etc/default/prometheus-mongodb-exporter` contains the configuration, which simply tells which instance to poll.
It also contains some doc, telling it's on port 9001 and seems to serve all interfaces by default.

First attempt at testing it does not work:

```bash
curl http://localhost:9001/metrics
curl: (52) Empty reply from server
```

`curl http://localhost:9001` is reponding so process is up.

Looking at log (`journalctl -xe -u prometheus-mongodb-exporter.service`), I see:
```bash
[2800400]: Listening on :9001 (scheme=HTTP, secured=no, clientValidation=no)
ter[2800400]: panic: runtime error: invalid memory address or nil pointer dereference
ter[2800400]: [signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x7de69d]
ter[2800400]: goroutine 31 [running]:
ter[2800400]: github.com/dcu/mongodb_exporter/collector.(*PreloadStats).Export(0x0, 0xc00014a360)
ter[2800400]:         github.com/dcu/mongodb_exporter/collector/metrics.go:363 +0x2d
ter[2800400]: github.com/dcu/mongodb_exporter/collector.(*ReplStats).Export(0xc000260700, 0xc00014a3
ter[2800400]:         github.com/dcu/mongodb_exporter/collector/metrics.go:352 +0x90
ter[2800400]: github.com/dcu/mongodb_exporter/collector.(*MetricsStats).Export(0xc000170460, 0xc0001
ter[2800400]:         github.com/dcu/mongodb_exporter/collector/metrics.go:448 +0x4fb
ter[2800400]: github.com/dcu/mongodb_exporter/collector.(*ServerStatus).Export(0xc0002d20b0, 0xc0001
ter[2800400]:         github.com/dcu/mongodb_exporter/collector/server_status.go:114 +0x2f6
ter[2800400]: github.com/dcu/mongodb_exporter/collector.(*MongodbCollector).collectServerStatus(0xc0
ter[2800400]:         github.com/dcu/mongodb_exporter/collector/mongodb_collector.go:132 +0xa5
ter[2800400]: github.com/dcu/mongodb_exporter/collector.(*MongodbCollector).Collect(0xc0001b0230, 0x
ter[2800400]:         github.com/dcu/mongodb_exporter/collector/mongodb_collector.go:87 +0x323
ter[2800400]: github.com/prometheus/client_golang/prometheus.(*Registry).Gather.func1()
ter[2800400]:         github.com/prometheus/client_golang/prometheus/registry.go:430 +0x193
ter[2800400]: created by github.com/prometheus/client_golang/prometheus.(*Registry).Gather
ter[2800400]:         github.com/prometheus/client_golang/prometheus/registry.go:522 +0xe23
ongodb-exporter.service: Main process exited, code=exited, status=2/INVALIDARGUMENT
```

It seems a known bug: https://github.com/dcu/mongodb_exporter/issues/122

We would have to use https://github.com/percona/mongodb_exporter

Hopefully there is a .deb on releases so I try to install it:

```bash
sudo apt remove prometheus-mongodb-exporter
# note: -L needed because there is a redirect
curl -L https://github.com/percona/mongodb_exporter/releases/download/v0.40.0/mongodb_exporter-0.40.0.linux-64-bit.deb --output /opt/mongodb_exporter-0.40.0.linux-64-bit.deb
apt install /opt/mongodb_exporter-0.40.0.linux-64-bit.deb
```

I have to enable it:
`systemctl enable --now mongodb_exporter`

It's not working. Indeed I had to create `/etc/default/mongodb_exporter`.

And it's not listening on same adress than the previous one, now it's 9216.

Now testing:
```bash
curl http://127.0.0.1:9216/metrics
... works ...
# also on private interface
curl http://10.1.0.102:9216/metrics
... works ...
```

## Proxying requests to prometheus exporter

We will use nginx to proxy request.

I created a free-exporters.openfoodfacts.org alias to off-proxy.openfoodfacts.org.

I created a basic file for the service in http.

Then used certbot to create the ssl configuration.

I use a map to map the uri I want with the right exporter address + port,
so I can reuse it in proxy_pass section.

Adding the basic auth:
```bash
apt install apache2-utils
mkdir /etc/nginx/.htpasswd
htpasswd -c /etc/nginx/.htpasswd/free-exporters  prometheus
```
I put the password in the keepassX as it's better not to loose it.

Then added the auth_basic and auth_basic_user_file directive to my site.

see [commit with config](https://github.com/openfoodfacts/openfoodfacts-infrastructure/commit/f7dab7bc7a2ce61b218213b8ef2559769436e2be)

## Adding to prometheus

I did do a test on the machine directly.

I can check the config using: `docker-compose exec prometheus promtool check config /etc/prometheus/config.yml`

I can reload prometheus with: `docker-compose kill -s SIGHUP prometheus`

I can go to https://prometheus.openfoodfacts.org/targets and see if my target is up or down.

I have to put the basic auth password in a file referenced by config, I will generate it in the CI later on.
I put it in `configs/prometheus/secrets/free-exporters.txt`

[See PR](https://github.com/openfoodfacts/openfoodfacts-monitoring/pull/106)