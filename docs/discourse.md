# Discourse

[Discourse](https://www.discourse.org/) is a forum application.

It is installed on our Proxmox infrastructure in a QEMU virtual machine (202).

## Software installation

Software is installed in `/var/discourse`.

We use the https://github.com/discourse/discourse_docker.git.

The docker configuration is contained in `config/app.yml`

It creates a unique docker container containing whole application, postgresql and redis database, and so on!

It defines volumes where all the data is found. It's in `/var/discourse/shared/standalone` and mounted in container as `/shared`

You might get a shell into the docker container using `./launcher enter app bash`.

## Mail

Mail is very important as a lot of notifications are sent by the forum.

Mail can be tested at https://forum.openfoodfacts.org/admin/email

We use [Promox mail gateway](./mail.md).

**⚠ Warning:** the sender email [have to be on main domain](./mail.md#only-domain), NOT forum.openfoodfacts.org.

## Software update

Please respect the following procedure:

1. Make a snapshot before upgrade.
2. Try to upgrade threw the web interface: https://forum.openfoodfacts.org/admin/upgrade (you need to be an admin)
3. Test the update during several days.
4. After several days, if everything is fine, you can delete the snapshot.

While upgrading via the web interface, you could possibly get this error message:
```
You are running an old version of the Discourse image.

Upgrades via the web UI are disabled until you run the latest image.

To do so log in to your server using SSH and run:
		cd /var/discourse
		git pull
		./launcher rebuild app
```
In this case, you have to upgrade in a Linux shell directly on the VM:

1. Get root access on ovh1: `sudo su root`
2. Connect yourself to the VM: `ssh 10.1.0.202`
3. `cd /var/discourse`
4. `git pull`
5. `./launcher rebuild app`


## Analytics with Matomo

We setup analytics with Matomo on the forum.

There is a theme: https://meta.discourse.org/t/matomo-analytics/33090 [^install_theme]

### setup

I created the website in Matomo. Site id is 8.

In Discourse:
* go to administration / Customize / theme
* install / from a git repository : https://github.com/discourse/discourse-matomo-analytics.git 
* Settings:
  * Include component on these themes: **Default**  (using button *add to all them*)
  * host url: `analytics.openfoodfacts.org`
  * website id: **8**
  * subdomain tracking: **yes**
  * do not track: **yes**
  * disable cookies: **yes** (keep GDPR compatibility)

Discourse is very specific in it's Content Security Policy headers, so we have to add an entry for Matomo.
* go to administration / settings / security
* in content security policy script src, add entry: `https://analytics.openfoodfacts.org/piwik.js`


[^install_theme]:
    More info on how to install a theme: https://meta.discourse.org/t/install-a-theme-or-theme-component/63682