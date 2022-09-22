# Mirabelle

"_Quelle est belle ma data !_" (_What a beautiful data!_)

The goal of this prototype is to allow playing with Open Food Facts data in SQL.

## Usages

* build rich/complex queries with a well known and widely deployed query language (SQL):
  * search for list of terms while excluding false-positive ones ([exemple](http://mirabelle.openfoodfacts.org/products?sql=select+code%2C+url+from+%5Ball%5D+where+%0D%0A++url+REGEXP%0D%0A++++%22%28test%7Cessai%29%22++++++%2F*+search+for+test+or+essai+*%2F%0D%0A++++++++++++++++++++++++%2F*+but+not+the+following+false+positive+*%2F%0D%0A++and+url+NOT+REGEXP%0D%0A++++%22%28contest%7Ccutest%7Cfontestad%7Cfontestorbes%7Cgreatest%7Cgroentestoof%7Chottest%7Cmlinotest%7Cphitest%7Csealtest%7Csetteteste%7Csmartest%7Csweetest%7Ctesta%7Ctestaroli%7Ctesteninom%7Ctestosterone%7Ctestun%7Cintestin%7Cwattestabchen%7Cdessaint%7Cessaim%29%22%0D%0A++order+by+rowid+limit+1000))
* CSV exports by countries.
* go beyond the 10,000 products CSV export per query on Open Food Facts website.
* export products that have changed until a given date.
* build your own views containing only the fields you want.
* communicate particular queries with their URLs.
* for admins, build particular view of the database; eg. a [simplified](http://mirabelle.openfoodfacts.org/products/simplified) view
* etc.


## Under the hood

Mirabelle is made with [Datasette](https://datasette.io). It's using very few processes and resources under the hood.

### 1. SQLite

It's starting with SQLite. Sqlite3-pcre is also installed to use REGEXP in SQL queries.

`sudo apt install sqlite3 sqlite3-pcre jq`

### 2. Datasette and its eco-system

`sudo pip install datasette`

`sudo datasette install datasette-copyable datasette-upload-csvs datasette-total-page-time`

### 3. Creating a dedicated user

`adduser -m off`

Also create a dedicated directory for the app: `mkdir /home/off/mirabelle`

### 4. Setup datasette and different scripts

* Create the database we will be using for Open Food Facts stats:
  `sqlite3 off-stats.db "create table products_from_owners(year TEXT,month TEXT,day TEXT,country TEXT,nb_products INTEGER);"`
* Create script to gather data everyday: [proplatform-stats.sh](proplatform-stats.sh).
* Add this script to crontab: `0 8 * * * bash /home/off/mirabelle/proplatform-stats.sh > /home/off/mirabelle/proplatform-stats.log`
* [products_daily_updates.sh](products_daily_updates.sh) is gathering the Open Food Facts CSV export and importing it into SQLite.
* [metadata.yml](metadata.yml) allows to add informations to datasette pages.
* [d-serve.sh](d-serve.sh) is launching datasette as a server. See [deploying Datasette](https://docs.datasette.io/en/stable/deploying.html) from the documentation.


### 5. Deploy datasette as a service

Create a [datasette service](datasette.service) for Systemd (`/etc/systemd/system/datasette.service`):
```ini
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

Let the `off` user access to the datasette service. Launch `visudo` and add the following code:
```bash
# Cmnd alias specification
Cmnd_Alias DATASETTE_CMDS = /bin/systemctl start datasette.service, /bin/systemctl stop datasette.service, /bin/systemctl restart datasette.service

# User privilege  specification
# [...]
off     ALL=(ALL) NOPASSWD: DATASETTE_CMDS
```

`off` user is now able to start, stop or restart datasette service.

* `off@mirabelle:~/mirabelle$ sudo systemctl start datasette.service`

* `off@mirabelle:~/mirabelle$ sudo systemctl stop datasette.service`

* `off@mirabelle:~/mirabelle$ sudo systemctl restart datasette.service`


### 6. Deploy nginx front web server

Deploying with nginx web server allows to build an efficient cache strategy:
* as the databases are read-only, we can cache them until their update by scripts
* when an update is done, the updater can purge the cache

`apt install nginx`

Create [/etc/nginx/sites-available/datasette.conf](datasette.conf).

`ln -s /etc/nginx/sites-available/datasette.conf /etc/nginx/sites-enabled/`

`rm /etc/nginx/sites-enabled/default`

`nginx -t # verify nginx config file syntax`

`systemctl reload nginx`

Verify all is working fine:
`curl http://127.0.0.1`

We also have to setup our front reverse proxy: [/etc/nginx/mirabelle.conf](mirabelle.conf).
