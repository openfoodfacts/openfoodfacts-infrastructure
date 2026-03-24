# Memcached role

This role installs and configures [Memcached](https://www.memcached.org/).

It uses git_based_config to configure memcached.

This role assumes that the `configure.yml` playbook was run before, especially for setting up the firewall rules (to open port `11211` if needed).