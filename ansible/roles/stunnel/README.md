# Stunnel role

This role installs and configures [Stunnel](https://www.stunnel.org/). We currently use Stunnel to secure connections between servers that are not on the same trusted network, using Pre-Shared Keys (PSK).

This role can be used to set up either a client or server Stunnel instance.

It uses git_based_config to configure stunnel.

To know more about our use of Stunnel, please refer to the [infrastructure documentation](https://openfoodfacts.github.io/openfoodfacts-infrastructure/stunnel/).

This role assumes that the `configure.yml` playbook was run before, especially for setting up the firewall rules.