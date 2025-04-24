# Reverse proxy role

- Installs `nginx` and it's configuration on a node.
- `nginx` is installed as a docker container

## Add services to the reverse proxy

### Setup the `reverse_proxy_websites` variable

In `host_vars/<node_name>/reverse-proxy.yml`, create the following varaible:

```yml
reverse_proxy_websites:
  - url: "example1.openfoodfacts.org"
    proxy_pass: "example1-webserver:80"
  - url: "example2.openfoodfacts.org"
    proxy_pass: "example2-webserver:80"
```

This will create a `nginx` configuration that passes:

- `example1.openfoodfacts.org` to container `example1-webserver` on port `80`
- `example2.openfoodfacts.org` to container `example2-webserver` on port `80`

The port defined in `proxy_pass` (here `80`) is the one used inside the webserver container.

In this example, the reverse proxy and the webserver are on the same host, but one could replace `example1-webserver` with the ip of a remote host.

### Configure the webserver container

**If the reverse proxy and the webserver are on the same host**, here is an example of a correctly configured webserver container:

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
