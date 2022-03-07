# Zammad

[Zammad](https://zammad.org/) is a tool for support.

It is installed in a VM at CQuest home (we should migrate it), in an LXC container.

It is exposed at https://support.openfoodfacts.org/

It was setup using zammad package (see [install docs](https://docs.zammad.org/en/latest/install/package.html)).

It has different services, all begining with the name `zammad-`. It uses postgresql.

It also uses Elasticsearch. Because we are in a container, heap memory size has to be configured manually through a file in `/etc/elasticsearch/jvm.options.d/memory.options`.  
`600m` seems like a good size.