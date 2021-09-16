# OpenFoodFacts Infrastructure
Sysadmin repository for the various parts of the Open Food Facts infrastructure.

## Requests

### Virtual Machines

<!-- VM table -->
|                                                                      Title                                                                      |State |   OS    | CPU #  |            RAM            |    SSD (Local)    |HDD (Remote)|                            Services                            |
|-------------------------------------------------------------------------------------------------------------------------------------------------|------|---------|--------|---------------------------|-------------------|------------|----------------------------------------------------------------|
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/53> robotoff-ml-net [#53]</a>                                       |open  |Debian 10|       8|64GB (Tensorflow, ANN)     |192GB [ML models]  |100GB       |Tensorflow + ANN + ElasticSearch                                |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/51> robotoff-net [#51]</a>                                          |open  |Debian 10|       4|16GB (DB 4GB, Services 8GB)|32GB               |100GB       |Robotoff API + Schedulers + Workers, PostgreSQL DB              |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/37> Wild School Eco-Score project [#37]</a>                         |open  |Debian 10|       4|16 Gb                      |30 Gb              |0           |MongoDB                                                         |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/36> slack-org [#36]</a>                                             |open  |Debian 10|       1|1 Gb                       |10 Gb              |None        |Node.js                                                         |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/29> adminer-org [#29]</a>                                           |open  |Debian 10|       2|512 Mb.                    |4 Gb or even less. |0           |Nginx, PHP, Adminer.                                            |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/28>Containers (x2) to build a replica set for OFF database [#28]</a>|open  |Debian 10|       4|32 GB                      |50 GB (DB = 20 GB).|0           |Mongodb.                                                        |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/27> feedme-org [#27]</a>                                            |open  |Debian 10|       3|3 Gb.                      |15 Gb.             |0           |PostgreSQL, Node.js, Nginx.                                     |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/24> Matomo [#24]</a>                                                |open  |Debian 10|No idea.|No idea.                   |No idea.           |No idea.    |LAMP                                                            |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/21> OFF wiki [#21]</a>                                              |open  |Debian 10|       2|3 Gb                       |14 Gb.             |14 Gb       |Apache, PHP, MySQL, Mediawiki.                                  |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/48> Tensorflow Model Experimentation [#48]</a>                      |closed|Debian 10|       8|64GB                       |32GB               |0GB         |Tensorflow experiments                                          |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/45> MongoDB dev [#45]</a>                                           |closed|Debian 10|       2|16GB                       |40GB               |            |MongoDB running in Docker                                       |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/41> ProductOpener .net [#41]</a>                                    |closed|Debian 10|       4|8GB (PO needs > 6GB)       |64GB               |64GB        |ProductOpener frontend + backend, MongoDB, PostgreSQL, Memcached|
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/40> robotoff-dev [#40]</a>                                          |closed|Debian 10|       4|8 Gb                       |32 Gb              |100 Gb      |robotoff, elastic search, tensorflow, postgresql                |
|<a href=https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/20> Robotoff .org [#20]</a>                                         |closed|Debian 10|       4|8 Gb                       |32 Gb              |100 Gb      |robotoff, elastic search, tensorflow, postgresql                |
<!-- VM table -->

<a href="https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/new?assignees=cquest&labels=container&template=vm-template.md&title="><img src="./scripts/add.png" style="background: transparent; vertical-align: middle" width="30"/>&nbsp;&nbsp;Request a VM</img></a>
