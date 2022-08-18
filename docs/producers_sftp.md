# Producers SFTP

We have a producer SFTP which is part of the producer platform.

This sftp is used by producers who send files for regular automated updates of their products.

The sftp is located on off1.openfoodfacts.org

The `/home/sftp` folder links to `/srv/sftp/` and contains home for sftp users.

## Adding a new sftp user

Use the script [`add_sftp_user.pl`](../scripts/off1/add_sftp_user.pl) (present in `/home/script`) with user root.