# 2023-09-27 / Expired SSL certificate for images.openfoodfacts.org on off2

## What happened

The SSL certificate expired the day before.

## Investigation

We temporarily moved images.openfoodfacts.org from ovh3 to off2, but not the renewal of the corresponding certificate.

## Solving (temporarily)

As we are likely to move back images.openfoodfacts.org to ovh3 soon, we just copied the newer Let's Encrypt files from ovh3 to off2, and restarted nginx.
The certificate was renewed on Sept 6 2023, it will expire on December 5 2023.

```
root@off2:/etc/letsencrypt# ls -lrt
total 42
-rw-r--r-- 1 root root  121 May 26  2018 cli.ini
drwxr-xr-x 5 root root    5 Jun 18  2021 renewal-hooks
-rw-r--r-- 1 root root  424 Jun 18  2021 ssl-dhparams.pem
-rw-r--r-- 1 root root 1143 Jun 18  2021 options-ssl-nginx.conf
drwxr-xr-x 3 root root    3 Jun 18  2021 accounts
drwx------ 4 root root    5 Jul  5  2021 live
drwx------ 4 root root    4 Jul  5  2021 archive
drwx------ 2 root root   52 Sep  6 22:32 keys
drwxr-xr-x 2 root root   52 Sep  6 22:32 csr
drwxr-xr-x 2 root root    4 Sep  6 22:32 renewal
drwxr-xr-x 9 root root   12 Sep 27 09:24 old
```
