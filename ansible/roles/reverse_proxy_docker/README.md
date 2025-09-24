# Reverse proxy role using NGINX

- Installs the `nginx` reverse proxy as a docker container and it's configuration.
- Installs `certbot` to manage HTTPS certificates and a cron to start it regularly.

## Add services to the reverse proxy

### Setup the variables

In `host_vars/<node_name>/reverse-proxy.yml`, create a variable with the following shape:

```yml
reverse_proxy_docker__websites:
  - url: "example1.openfoodfacts.org"
    proxy_pass: "example1-webserver:80"
  - url: "example2.openfoodfacts.org"
    proxy_pass: "example2-webserver:80"
    username: "off" # optional
    password: "{{ secrets_off_password }}" # optional

reverse_proxy_https_cert_domains:
  - "openfoodfacts.org" # that's actually the default
```

In `host_vars/<node_name>/reverse-proxy-secrets.yml`, create a variable with the following shape:

```yml
reverse_proxy_certbot_ovh_application_key: "[...]"
reverse_proxy_certbot_ovh_application_secret: "[...]"
reverse_proxy_certbot_ovh_consumer_key: "[...]"
```

In this example, the task will create a `nginx` configuration that passes:

- `example1.openfoodfacts.org` to container `example1-webserver` on port `80`
- `example2.openfoodfacts.org` to container `example2-webserver` on port `80`

The port defined in `proxy_pass` (here `80`) is the one used inside the webserver container.

In this example, the reverse proxy and the webserver are on the same host, but one could replace `example1-webserver` with the ip of a remote host (on a local subnet preferably, for security reasons).

#### Adding Basic Auth

It is possible to setup a basic user/password authentification on a specific website by adding the two optional parameters `username` and `password` (see the example on `example2.openfoodfacts.org`).

**Remember to store the password in a `git-crypted`file (ending in`...-secrets.yml`).**

I recommend to choose a randomly-generated 21 characters password from the `a-zA-Z0-9!@#$%^*` characterset. Run this command to generate such a random password: `tr -dc 'a-zA-Z0-9!@#$%^*' < /dev/urandom | head -c 21`.

#### HTTPS Certificates

The `reverse_proxy_https_cert_domains` variable will create a wildcard https certificate for the domains in this list (it defaults to `["openfoodfacts.org"]`).

To generate those certificates, we use a DNS challenge and the OVH API. See [docs/nginx-reverse-proxy.md How to add wildcard certificates](../../../docs/nginx-reverse-proxy.md) on how to generate them, and put the credentials in the variables stated above.

For security reasons, generate a new OVH API key for each node.

### Configure the webserver container

#### When the reverse proxy and the webserver are on the same host

The docker compose of the service should look like:

```yml
services:
  example1-webserver:
    build: .
    restart: unless-stopped
    networks:
      - reverse_proxy_network

networks:
  reverse_proxy_network:
    external: true
```

Adding the `reverse_proxy_network` allows the reverse proxy and the webserver to communicate.

⚠️ You should **NOT** use `ports:` in the docker compose, this network should be enough. Moreover, only apply the `reverse_proxy_network` to services that need access to internet. For exemple, a database only used locally shouldn't be connected to `reverse_proxy_network`.

#### When the reverse proxy and the webserver are NOT on the same host

The docker compose of the service should look like:

```yml
services:
  example1-webserver:
    build: .
    restart: unless-stopped
    ports:
      - "7777:7777" # or other ports...
```

In that case, it is necessary to open port(s).

## Debugging

- The `certbot` is started regularly by a cron. If necessary, you can check it's logs:

```sh
cd /opt/reverse_proxy
docker compose logs certbot -tn 25
```

Shows the last 25 lines of logs. Note that the timestamps are in UTC time. You can also check the `/opt/reverse_proxy/certbot/cron.log`, which saves the last execution.
