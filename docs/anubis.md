[Anubis](https://anubis.techaro.lol/) is a kinf of reverse-proxy allowing to filter bots.

## Update

The update is done by downloading the new version and installing it again with `apt` (see, [Installation](#installation) below).

Have a look at the [releases page](https://github.com/TecharoHQ/anubis/releases).


## Configuration

The [`wiki.env`](/confs/ovh1-reverse-proxy/anubis/wiki.env) file is containing all the environment variables in TOML format.

The [`wiki.botPolicies.yaml`](/confs/ovh1-reverse-proxy/anubis/wiki.botPolicies.yaml) file is containing the bot policies.

We have configured Anubis to run as a reverse proxy in front of the wiki application, and behind nginx reverse proxy. It possible to use it through sockets too.

We started from the default botPolicies of Anubis but tweak it in several ways:

* only keep rules for known bots that give negative weights to legit bots (search engines)
* give negative weights to user with an authentication cookie
* give negative weights to ovh1 url; this is needed because the mediawiki visual editor does a request to the api on the wiki public url, to get the content of the page to edit
* simplify the final rules and challenge every one but negative weights


## Usage

The Debian package installs a systemd service named `anubis`. To enable and start it, use the following commands:

```bash
sudo systemctl enable anubis@wiki.service
sudo systemctl start anubis@wiki.service
```
You can check the status of the service with:

```bash
sudo systemctl status anubis@wiki.service
```
To view the logs of the Anubis service, use:

```bash
sudo journalctl -u anubis@wiki.service -f # display the logs in real-time.
```

If you make changes to the configuration files, restart the service with:

```bash
sudo systemctl restart anubis@wiki.service
```



## Installation

We have chosen the "[native package](https://anubis.techaro.lol/docs/admin/native-install)" way.

```
wget https://github.com/TecharoHQ/anubis/releases/download/v1.23.1/anubis_1.23.1_arm64.deb

sudo apt install ./anubis_1.23.1_arm64.deb

sudo cp /usr/share/doc/anubis/botPolicies.yaml /etc/anubis/gitea.botPolicies.yaml

sudo cp /etc/anubis/default.env /etc/anubis/wiki.env
```

## Nginx Configuration

Here is an example of Nginx configuration to use Anubis as a reverse proxy for a wiki application:

```nginx
server {
    listen 80;
    server_name wiki.example.com;
    location / {
        proxy_pass http://localhost:8100; # Assuming Anubis is listening on port 8100
                                          # Then Anubis will forward requests to the actual wiki application
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Anubis-Status $http_x_anubis_status;
    }
}
```
