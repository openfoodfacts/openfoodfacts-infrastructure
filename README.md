# OpenFoodFacts Infrastructure
Sysadmin repository for the various parts of the Open Food Facts infrastructure.
We have a [specific repository regarding monitoring](https://github.com/openfoodfacts/openfoodfacts-monitoring)


## Documentation

The infrastructure documentation is as follows:

- [Mail](./docs/mail.md) - servers mail setup
- [Linux Server](./docs/linux-server.md) - servers general setup
- [Proxmox](./docs/promox.md) - about proxmox management
- [CICD](./docs/cicd.md) - continuous integration and deployment
- [Observability](./docs/observability.md) - doc on monitoring / logs / etc.
- [Docker Onboarding](./docs/docker_onboarding.md)
- [Docker Infrastructure](./docs/docker_architecture.md)
- [Virtual Machines](#virtual-machines)

Some services:

- [Zammad](./docs/zammad.md) for support
- [Matomo](./docs/matomo.md) for web analytics


## Requests

### Virtual Machines

<!-- VM table -->
|                                                                      Title                                                                      |State |              OS              | CPU #  |            RAM            |    SSD (Local)    |   HDD (Remote)   |                                       Services                                        |
|-------------------------------------------------------------------------------------------------------------------------------------------------|------|------------------------------|--------|---------------------------|-------------------|------------------|---------------------------------------------------------------------------------------|
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/80>CT for new blog engine [#80]</a>                                 |open  |Debian stable.                |3 CPU.  |2 GB.                      |10 GB              |--                |LAMP + wordpress.                                                                      |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/76>CT for Folksonomy Engine API dev [#76]</a>                       |open  |Default to Debian last Stable.|2       |1 GB                       |12 GB.             |-                 |PostgreSQL, Python3.                                                                   |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/55> impactestimator-net [#55]</a>                                   |open  |Debian 11                     |1       |1GB                        |1Gb                |0                 |https://github.com/openfoodfacts/impactestimator                                       |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/53> robotoff-ml [#53]</a>                                           |open  |Debian 11                     |8       |96GB (Tensorflow, ANN)     |192GB [ML models]  |100GB             |Tensorflow + ElasticSearch                                                             |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/51> robotoff-net [#51]</a>                                          |open  |Debian 11                     |4       |16GB (DB 4GB, Services 8GB)|92GB               |0GB               |Robotoff API + Schedulers + Workers, PostgreSQL DB                                     |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/37> Wild School Eco-Score project [#37]</a>                         |open  |Debian 10                     |4       |16 Gb                      |30 Gb              |0                 |MongoDB                                                                                |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/36> slack-org [#36]</a>                                             |open  |Debian 10                     |1       |1 Gb                       |10 Gb              |None              |Node.js                                                                                |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/29> adminer-org [#29]</a>                                           |open  |Debian 10                     |2       |512 Mb.                    |4 Gb or even less. |0                 |Nginx, PHP, Adminer.                                                                   |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/28>Containers (x2) to build a replica set for OFF database [#28]</a>|open  |Debian 10                     |4       |32 GB                      |50 GB (DB = 20 GB).|0                 |Mongodb.                                                                               |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/27> feedme-org [#27]</a>                                            |open  |Debian 10                     |3       |3 Gb.                      |15 Gb.             |0                 |PostgreSQL, Node.js, Nginx.                                                            |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/21> off-wiki-org [#21]</a>                                          |open  |Debian 10                     |2       |3 Gb                       |14 Gb.             |14 Gb             |Apache, PHP, MySQL, Mediawiki.                                                         |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/71>New VM QEMU for prod docker containers [#71]</a>                 |closed|Debian 11 (stable)            |8       |24 GB                      |256 GB.            |-                 |Services deployed in production:                                                       |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/59> monitoring [#59]</a>                                            |closed|Debian 11                     |4       |32GB                       |64GB               |500GB (ovh3 mount)|Docker: ElasticSearch (Kibana?, Logstash?), Grafana, InfluxDB, Prometheus, Alertmanager|
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/45> mongo-dev [#45]</a>                                             |closed|Debian 10                     |2       |16GB                       |40GB               |                  |MongoDB running in Docker                                                              |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/41> off-net [#41]</a>                                               |closed|Debian 10                     |4       |16GB (PO needs > 6GB)      |192GB              |0GB               |ProductOpener frontend + backend, MongoDB, PostgreSQL, Memcached                       |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/40> robotoff-dev [#40]</a>                                          |closed|Debian 10                     |4       |8 Gb                       |32 Gb              |100 Gb            |robotoff, elastic search, tensorflow, postgresql                                       |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/24> Matomo [#24]</a>                                                |closed|Debian 10                     |No idea.|No idea.                   |No idea.           |No idea.          |LAMP                                                                                   |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/20> robotoff-org [#20]</a>                                          |closed|Debian 10                     |4       |8 Gb                       |32 Gb              |100 Gb            |robotoff, elastic search, tensorflow, postgresql                                       |
<!-- VM table -->

<a href="https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/new?assignees=cquest&labels=container&template=vm-template.md&title="><img src="./scripts/add.png" style="background: transparent; vertical-align: middle" width="30"/>&nbsp;&nbsp;Request a VM</img></a>
