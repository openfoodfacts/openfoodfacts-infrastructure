# 2024-11-04 Configure AWS S3 copy of CSV exports with MinIO mc on Product Opener containers

The CSV and RDF database exports on OFF, OBF, OPF and OPFF are copied to Amazon S3.

Instructions below for opff, same for other flavors.

In the opff container, as off:

```bash
curl https://dl.min.io/client/mc/release/linux-amd64/mc   --create-dirs   -o $HOME/minio-binaries/mc
chmod u+x $HOME/minio-binaries/mc
```

as root:

```bash
mv /home/off/minio-binaries/mc /usr/local/bin/mc
```

on off2 host, I copy the .aws and .mc configuration from off container to the obf, opf, opff containers:

```bash
cp -a /zfs-hdd/pve/subvol-113-disk-0/home/off/.aws /zfs-hdd/pve/subvol-118-disk-0/home/off/
cp -a /zfs-hdd/pve/subvol-113-disk-0/home/off/.mc /zfs-hdd/pve/subvol-118-disk-0/home/off/
```

in the opff container, as off, I verify that mc works:

```bash
off@opff-new:~$ (opff) mc ls s3/
[2024-10-03 09:47:44 UTC]     0B openfoodfacts-ds/
[2023-04-04 05:01:31 UTC]     0B openfoodfacts-images/
[2023-04-04 05:01:07 UTC]     0B openfoodfacts-images-logs/
```

Create a bucket:

```bash
mc mb s3/openpetfoodfacts-ds
```


