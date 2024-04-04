# 2023-11-28 setup a google drive backup

## Create a container

On ovh3 I created a container 150.
I runned the postinstall scrpit

I put a small size for the main disk (50G) it's only for the system.

But after VM creation I added a disk of 500G through proxmox interface.

I also made a user for me for I will need to connect with ssh (using mkuseralias script).


## Techbot account

I created a techbot account on google openfoodfacts.

I gave it the reader right on whole google drive.

### Trying grive2

### Building grive2

Following instructions on https://yourcmc.ru/wiki/Grive2#Build_debian_package

Inside container, I clone the repository and build the deb package:

```bash
cd /opt
git clone https://github.com/vitalif/grive2.git
cd grive2/
git log|head
    Author: Vitaliy Filippov <vitalif@yourcmc.ru>
    Date:   Sat Dec 10 13:20:39 2022 +0300

        Cache layers during Docker build, take source from the current dir instead of cloning

    commit eb82bfe28b9e796721ffdffc7426684350f71a8a

apt install dpkg-dev
# note I get this list by a first run of dpkg-buildpackage
# There is a '|' in the output to tell you to choose between two libraries for libcurl4
apt install git cmake build-essential  debhelper pkg-config zlib1g-dev libcurl4-openssl-dev libboost-filesystem-dev libboost-program-options-dev libboost-test-dev libboost-regex-dev libexpat1-dev libgcrypt-dev libyajl-dev
# I did not use -j4 because it's harder to read output of parrallel compilations, and also because of limited memory
dpkg-buildpackage
cd ..
```

and install:

```bash
cd /opt
dpkg -i grive_0.5.3_amd64.deb
```

### First sync - authentication

Following https://yourcmc.ru/wiki/Grive2#Usage

I go to `/mnt/gdrive-backup/`

Start a screen: `screen -S grive`

```bash
cd /mnt/gdrive-backup/
grive -a
-----------------------
Please open this URL in your browser to authenticate Grive2:
...
```

You get a url that you must open in a browser.
But this url have a redirect_uri parameter which redirect to localhost with a specific port.
In my case the port is 57125 (but it changes).

To have auth work, I have to redirect this local port to the container local port thanks to ssh.

On my machine:
```bash
ssh gdrive-backup -L 57125:1217.0.0.1:57125
```

I can then copy paste the url in a browser tab where I am authenticated as techbot,
after going through the google auth wizard, I get redirected and got the message:
```bash
Authenticated successfully. Please close the page
```

To be able to use google auth, we either need to use w3m
or to have localhost:58043 redirecting to the container.

### It does not work for us

Finally I get those problems after testing:

1. grive does not synchronize google documents ! (while that's what we need ! To sync google docs)
2. It does not seem to support synchronizing shared drive (and here again, that's what we need)


## rclone


### Install

We need unzip installed.
```bash
sudo apt install unzip
```

Then following https://rclone.org/install/

```bash
sudo -v ; curl https://rclone.org/install.sh | sudo bash
```

## Config

### Creating an OAuth profile

I prefer to do that as a backup of many file can lead to many requests.

I followed https://rclone.org/drive/#making-your-own-client-idX
* logged into https://console.developers.google.com/
* select projects --> create new
  * name: "drive backup"
  * org and zone: openfoodfacts.org
* "ENABLE APIS AND SERVICES" search for "Drive", and enable the "Google Drive API".
* Click "Credentials" in the left-side panel (not "Create credentials", which opens the wizard).
*  "CONFIGURE CONSENT SCREEN"
   * first step (creation):
     * user type: external --> no ! use internal (see below)
     * click create
   * second step (app config):
       * app name: rclone
       * assistance email: tech - at - openfoodfacts.org
       * dev email: tech - at -  openfoodfacts.org
       * click save
   * third step (scopes) :
       * click on add and remove application scope
       * select: .../auth/docs, .../auth/drive,  ../auth/drive.metadata.readonly 
       * click update
       * click save and continue
    * 4th step (tests users):
      * click add user
      * add techbot@openfoodfacts.org
      * click save and continue

I first use application type external,
but finally I decided to go for internal app (this is fine for our use)
So in OAuth consent screen, I changed type to "Internal".
So above scenario might have some unecessary step.

Add an 0Auth account:
* click on "credentials" on the right panel, to come back to it
* click on "+ CREATE CREDENTIALS" button at the top of the screen, then select "OAuth client ID".
  * Choose an application type of "Desktop app", name "rclone backup drive on ovh3" and click "Create"

### Adding drive

following https://rclone.org/drive/

I will first create the drive corresponding to Open Food Facts.

I get the drive id in the url of the drive (after folders/)

```
rclone config
...
No remotes found, make a new one?
n) New remote
s) Set configuration password
q) Quit config
n/s/q> n

Enter name for new remote.
name> off-gdrive

Option Storage.
Type of storage to configure.
Choose a number from below, or type in your own value.
...
18 / Google Drive
   \ (drive)
...
Storage> drive

Option client_id.
Google Application Client Id
Setting your own is recommended.
See https://rclone.org/drive/#making-your-own-client-id for how to create your own.
If you leave this blank, it will use an internal key which is low performance.
Enter a value. Press Enter to leave empty.
client_id> ***********.apps.googleusercontent.com

Option client_secret.
OAuth Client Secret.
Leave blank normally.
Enter a value. Press Enter to leave empty.
client_secret> ********************

Option scope.
Comma separated list of scopes that rclone should use when requesting access from drive.
Choose a number from below, or type in your own value.
Press Enter to leave empty.
...
scope> drive.readonly

Option service_account_file.
Service Account Credentials JSON file path.
...
service_account_file> 

Edit advanced config?
...
y/n> n
... (all the rest is default)
```

We then come to authorization:

```
2023/11/28 15:15:21 NOTICE: Make sure your Redirect URL is set to "http://127.0.0.1:53682/" in your custom config.
2023/11/28 15:15:21 NOTICE: If your browser doesn't open automatically go to the following link: http://127.0.0.1:53682/auth?state=******
2023/11/28 15:15:21 NOTICE: Log in and authorize rclone for access
```

So I first did a port redirection with ssh from my machine:
```bash
ssh gdrive-backup -L 53682:127.0.0.1:53682
```
and opened the url on my machine, but in a tab where I am authenticated as techbot.
I followed the auth screen and finally got a:
```
Success!
All done. Please go back to rclone.
```

It proceed on the server:
```
Configure this as a Shared Drive (Team Drive)?

y) Yes
n) No (default)
y/n> y

Option config_team_drive.
Shared Drive
Choose a number from below, or type in your own string value.
Press Enter for the default (0AHYW2qKn7jMpUk9PVA).
 1 / OFF Fellowship drive
   \ (*******)
 2 / Open Food Facts
   \ (*******)
config_team_drive> 2

...

Keep this "off-gdrive" remote?
y) Yes this is OK (default)
e) Edit this remote
d) Delete this remote
y/e/d> y
```

**FIXME** add second drive.


### First sync

see https://rclone.org/commands/rclone_copy/

As simple as:
```bash
rclone sync off-gdrive: /mnt/gdrive-backup/Open-Food-Facts/
```

We use sync and not copy because sync also remove files deleted on remotes.
We will however keep old files through the ZFS snpashots mechanism.

#### Problem in first think

Looking at the process after a while, it did stop because the disk was full with 500 G of data

I augment the zfs dataset size with `pct resize mp0 2T` but I was supsicious.

I look at properties of the drive in Google drive, and it says it was 105G of data.

I then issue a  `du -sh *|sort -h` in `/mnt/gdrive-backup/Open-Food-Facts` and saw `Community Management` folder taking a lot of space !
After investigation, it was dowloading several time because there is a shortcut of the same folder inside the folder.

I though I configured the drive to not 250000download linked content, but it seems not to be the case !

https://rclone.org/flags/ helps me get the flag I want to edit: `--drive-copy-shortcut-content`

So I did a [`rclone config update`](https://rclone.org/commands/rclone_config_update/):
```bash
rclone config update off-gdrive copy_shortcut_content=false config_refresh_token=false
```

```bash
rclone config update  off-gdrive copy_shortcut_content=0 config_refresh_token=false
```

I also changed some other flags for efficiency:
```bash
rclone config update off-gdrive  buffer_size=256M fast_list=true config_refresh_token=false
```

I did a research on the drive and found a lot of shorcuts, so instead of cleaning the mess,
I removed all content and did the sync again !

But it was not enough !

So I tried to use skip shortcuts option:

```bash
rclone config update off-gdrive   config_refresh_token=false
```


### Systemd service

I created `rclone_backup@.{service,timer}` and linked it.

I renamed `/mnt/gdrive-backup/Open Food Facts` to `/mnt/gdrive-backup/off-gdrive` to be consistent

Then activate:

```
systemctl daemon-reload
systemctl enable --now rclone_backup@off-gdrive
```