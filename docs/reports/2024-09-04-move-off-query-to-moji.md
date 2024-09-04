# 2024-09-04 Move off query to moji

Because we have spurious reboots of off1, we want to move off-query to moji server.

Because Moji server is ipv6 only, we will:
* reach off-query through stunnel on off2
* use the reverse proxy + stunnel if needed to make it publicly available
* off-query will reach redis on off2 through stunnel, as robotoff already does

We will:
* deploy off-query on moji
* rsync data to moji and start it to catch up
* create a stunnel client container on off2
* test everything

## Deploying on moji

See PR from Raphaël


### Configuring stunnel server on moji

I ssh'ed on moji and used `sudo pct enter 102`

Created the psk file:
```bash
echo moji-off-query:$(pwgen 32) > /etc/stunnel/psk/off-query-psk.txt
chmod go-rwx -R /etc/stunnel/psk/
```

Modified the config to add off-query:
```ini
[off-query]
client = yes
accept = 127.0.0.1:16001
connect = 2a06:c484:5::102:16001
ciphers = PSK
PSKsecrets = /etc/stunnel/psk/off-query-psk.txt
```

restart stunnel, and verify it's still working:
```bash
systemctl restart stunnel@off
systemctl status stunnel@off
```

Verify https://robotoff.openfoodfacts.org/api/v1/health is still working (served by this stunnel server).

## Creating stunnel client on off2

### Creating stunnel-client container on off2

Created container ([see doc](../proxmox.md/#how-to-create-a-new-container)):
* 103, stunnel-client, unpriviledge, with nesting.
* using debian 12
* disk 6G noatime, 2cores, 512Mb memory

And did usual configurations, and cloned the [off-infrastructure repository](../how-to-have-server-config-in-git.md)

### Installing and configuring stunnel client

Install stunnel `apt install stunnel`

Copy useful configurations in git (taking inspiration from ovh-stunnel-client):
* log rotate override:
  `ln -s /opt/openfoodfacts-infrastructure/confs/off-stunnel-client/systemd/system/logrotate.service.d /etc/systemd/system/`
* email failures notifications
  `ln -s /opt/openfoodfacts-infrastructure/confs/off-stunnel-client/systemd/system/email-failures@.service /etc/systemd/system/`
* stunnel override:
  `ln -s /opt/openfoodfacts-infrastructure/confs/off-stunnel-client/systemd/system/stunnel@.service.d /etc/systemd/system/`
* stunnel config for off:
  `ln -s /opt/openfoodfacts-infrastructure/confs/off-stunnel-client/stunnel/off.conf /etc/stunnel/`

Notify systemd: `systemctl daemon-reload`

Create psk file in `/etc/psk/off-query-psk.txt`, copying content from moji stunnel server.
Ensure privacy `chmod go-rwx -R /etc/stunnel/psk/`.

Start and enable stunnel: `systemctl enable --now stunnel@off.service`

Verify:
```bash
systemctl status stunnel@off.service
```