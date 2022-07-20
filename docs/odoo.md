# Install

The current test instance (Odoo 15) have been installed with the following commands.

* Install Debian 11
* `apt install postgresql -y`
* `apt install wkhtmltopdf`
* `apt install gnupg gnupg1 gnupg2`
* `wget -O - https://nightly.odoo.com/odoo.key | apt-key add -`
* `echo "deb http://nightly.odoo.com/15.0/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list`
* `apt-get update && apt-get install odoo`
* Setup Nginx proxy

# Start/stop

```bash
sudo systemctl start odoo # (starts service)
sudo systemctl stop odoo # (stops service)
sudo systemctl restart odoo # (restarts Service)
sudo systemctl status odoo # (status of service)
sudo systemctl enable odoo # (starts service at boot)
sudo systemctl disable odoo # (disables service at boot)
```

# Install a new module

Examples:
```bash
cd /usr/lib/python3/dist-packages/odoo/addons
wget https://apps.odoo.com/loempia/download/formio/15.0/formio.zip
unzip formio.zip
```

```bash
cd /usr/lib/python3/dist-packages/odoo/addons
wget https://apps.odoo.com/loempia/download/mass_editing/15.0/mass_editing.zip
unzip formio.zip
```

## Contributed modules from OCA store

OCA hosts hundreds of modules. Those ones are disseminated into dozens of git repositories. For example, the Mass Editing module can be find inside the https://github.com/OCA/server-ux repository.

```bash
cd /usr/lib/python3/dist-packages/odoo/addons
git clone https://github.com/OCA/server-ux
cd business-requirement
git checkout 15.0 #for the version 15.0: adapt according to desired version
# Update the addon path in your `odoo.conf` file
```


Then, as an admin, in Odoo:
* Apps menu
* `Update Apps List` sub-menu
* then find the app in the `search` field

# Create a test environment from production instance

```shell
pct snapshot 110 temp # create a "temp" named snapshot of CT with ID 120 (production)
pct clone 110 112 --hostname connect-staging --snapname temp # take the snapshot and create a new CT (112) named connect-staging
pct delsnapshot 110 temp # del production snapshot
# New CT configuration
pct set 112 --cores 2 --memory 4096 --net0 name=eth0,bridge=vmbr0,gw=192.168.0.254,ip=192.168.0.112/24
pct start 112
# pct exec 112 .................. # a way to execute things on a CT from host

# TO BE CONTINUED
```
