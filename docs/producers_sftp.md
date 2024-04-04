# Producers SFTP

We have a producer SFTP which is part of the producer platform.

This sftp is used by producers who send files for regular automated updates of their products.

The sftp is located on the reverse proxy container (because it needs it's own network interface).

The sftp directory is a ZFS dataset in `zfs-hdd/off-pro/sftp`.
It is mounted as `/mnt/off-pro/sftp`:
* in the reverse proxy to give access to producers themselves (through sftp)
* and in off-pro container to give access to files to the producers platform.

In the reverse proxy container, the sftp is configured in /etc/ssh/sshd_config.d/sftp.conf which is a symlink to `confs/proxy-off/sshd_config/sftp.conf` in this repository.

If a producer want's to connect with a key, put the public key in a file named `/mnt/off-pro/sftp/<username>_authorized_keys`.

## Adding a new sftp user

Use the script `add_sftp_user.pl` (present in `script/off-proxy`) with user root in the reverse proxy container.

**:fire: IMPORTANT :fire::** every user **must be in `sftponly` group** and only in this one.

You may eventually communicate the server key fingerprint to the producer 
(get it with `ssh-keyscan $(hostname) | ssh-keygen -lf -`)

It's better to test access before sending the mail to the producer:

```bash
lftp sftp://user@sftp.openfoodfacts.org
password:
> ls
```

(issue at least an `ls` because `lftp` only try to connect at the first command)
