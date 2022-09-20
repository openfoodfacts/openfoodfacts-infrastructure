# Mirabelle

"_Quelle est belle ma data !_" (_What a beautiful data!_)

The goall of this prototype is to allow playing with Open Food Facts data in SQL.

## Usages

* Allows to build rich/complex queries with a well known and widely deployed query language (SQL).
* Allows CSV exports by countries.
* Allows to 


## Under the hood

Mirabelle is made with [Datasette](https://datasette.io). It's using very few process and resources under the hood.

1. SQLite

It's starting with SQLite. Sqlite3-pcre is also installed to use REGEXP in SQL queries.

`sudo apt install sqlite3 sqlite3-pcre jq`


2. Datasette and its eco-system.

`sudo pip install datasette`
`sudo datasette install datasette-copyable datasette-upload-csvs datasette-total-page-time`

3. Creating a dedicated user.

`adduser -m off`

4. Setup datasette and different scripts.

* Create the database we will be using for Open Food Facts stats: `sqlite3 off-stats.db "create table products_from_owners(year TEXT,month TEXT,day TEXT,country TEXT,nb_products INTEGER);"`
* Create script to gather data everyday: `proplatform-stats.sh`.
* Add this script to crontab: `0 8 * * * bash /home/off/mirabelle/proplatform-stats.sh > /home/off/mirabelle/proplatform-stats.log`
* `products_daily_updates.sh` is gathering the Open Food Facts CSV export and importing it into SQLite.
* `metadata.yml` allows to add informations to datasette pages.
* `d-serve.sh` is launching datasette as a server.


5. Deploy datasette as a service.

Create a datasette service (`/etc/systemd/system/datasette.service`):
```toml
[Unit]
Description=Datasette
After=network.target

[Service]
Type=simple
User=off
Environment=DATASETTE_SECRET=3ffdab10e0919f1760f4cf0e8db999285e860b61ed3294e847e480ab01624148
WorkingDirectory=/home/off/mirabelle
ExecStart=/home/off/mirabelle/d-serve.sh
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Let the `off` user access to datasette service. Launch `visudo` and add the following code:
```bash
# Cmnd alias specification
Cmnd_Alias DATASETTE_CMDS = /bin/systemctl start datasette.service, /bin/systemctl stop datasette.service, /bin/systemctl restart datasette.service

# User privilege  specification
# [...]
off     ALL=(ALL) NOPASSWD: DATASETTE_CMDS
```

`off` user is now able to start, stop or restart datasette service.

`off@mirabelle:~/mirabelle$ sudo systemctl start datasette.service`

`off@mirabelle:~/mirabelle$ sudo systemctl start datasette.service`

