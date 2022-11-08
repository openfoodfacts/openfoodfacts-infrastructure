# Odoo: our relationship management (connect.openfoodfacts.org)

Odoo is a very rich tool: we need to think a little bit before doing things.
Some actions can't be canceled; for example: some modules, when installed, can't be removed.
 
Quick guidelines to follow:
1. Technical and functional admins rights should be separated.
2. Usages should be clearly expressed and modules should be discussed before implemented. An issue have to be open before each module or group of module installation.
3. Tests need to be made in a staging environement.


## Install

The current test instance (Odoo 15) have been installed with the following commands.

* Install Debian 11
* `apt install postgresql -y`
* `apt install wkhtmltopdf`
* `apt install gnupg gnupg1 gnupg2`
* `wget -O - https://nightly.odoo.com/odoo.key | apt-key add -`
* `echo "deb http://nightly.odoo.com/15.0/nightly/deb/ ./" >> /etc/apt/sources.list.d/odoo.list`
* `apt-get update && apt-get install odoo`
* Setup Nginx proxy

## Start/stop

```bash
sudo systemctl start odoo # (starts service)
sudo systemctl stop odoo # (stops service)
sudo systemctl restart odoo # (restarts Service)
sudo systemctl status odoo # (status of service)
sudo systemctl enable odoo # (starts service at boot)
sudo systemctl disable odoo # (disables service at boot)
```

## Install a new module

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

### Contributed modules from OCA store

OCA hosts hundreds of modules. Those ones are disseminated into dozens of git repositories. For example, the Mass Editing module can be find inside the https://github.com/OCA/server-ux repository.

Note: In github, always search for the 15.0 branch
(if 15.0 is your version) because the front page might be that of 14.0
and mislead you on supported versions.

In this case we will add all addons of the repository:

```bash
cd /usr/lib/python3/dist-packages/odoo/addons
# for odoo version 15.0: adapt according to desired version
git clone https://github.com/OCA/server-ux --branch 15.0
```

Update the addon path in your `/etc/odoo/odoo.conf` file to add our new directory
```bash
addons_path = /usr/lib/python3/dist-packages/odoo/addons,/usr/lib/python3/dist-packages/odoo/addons/server-ux
```

Look at the `__manifest__.py`, for the product you want to install, and see if there are python modules to be installed (python dependencies). Also do that for any product, it depends on.

Restart Odoo:

```bash
systemctl restart odoo
```


Then, as an admin, in Odoo:
* pass in developer mode (ctrl+K debug:)
* Apps menu
* `Update Apps List` sub-menu
* then find the app in the `search` field (eventually remove the "app" filter if you installed a utility)

## Create a test environment from production instance

```shell
# previously verify that CT 112 is currently connect-staging, and delete it before renewing it
pct snapshot 110 temp # create a "temp" named snapshot of CT with ID 120 (production)
pct clone 110 112 --hostname connect-staging --snapname temp # take the snapshot and create a new CT (112) named connect-staging
pct delsnapshot 110 temp # del production snapshot
# New CT configuration
pct set 112 --cores 2 --memory 4096 --net0 name=eth0,bridge=vmbr0,gw=10.0.0.1,ip=10.1.0.112/24
pct start 112
# pct exec 112 .................. # a way to execute things on a CT from host

# TO BE CONTINUED
```
