# Rclone

We use rclone to backup our google data.

## Usage

The Container 150 on ovh3 is setup to backup the Google Drive.

It has a separate drive for the backups mounted in `/mnt/gdrive-backup`.

The configuration for the drive (without password !) is in the git. Use `rclone config redacted > confs/gdrive/rclone-drives-config` to update it, verify before committing that there are no passwords.


## Systemd service

We use a timer and service to launch rclone.

The instance name must correspond to the rclone driver name and to the folder where we backup.


## Setup a new drive

see [2023-11-28 setup a google drive backup](reports/2023-11-28-google-drive-backup-setup.md)
