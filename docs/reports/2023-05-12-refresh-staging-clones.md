# 2022-05-12 refresh staging clones

We have zfs clones of volumes for staging data. We need to refresh the clone to be up to date.

I verified I can login on the VM for stagging dockers (using 10.1.0.200) from ovh3.

## Using NFS Volumes

We want to avoid having to umnount things globally in 200, so I moved to using direct nfs mounts.

I made [a PR to change external volume creation](https://github.com/openfoodfacts/openfoodfacts-server/pull/8422). This PR also adds volume prefixes.
Because of prefix added, I didn't have the urge to remove previous volumes.

Latter I did have to [add the no_lock option](https://github.com/openfoodfacts/openfoodfacts-server/pull/8443) so that product opener can add locks, otherwise it's impossible to display a product.

After deploy happens, I removed old volumes. I also checked that local volumes (`html_data` and `podata`, renamed to `po_html_data` and `po_podata`) didn't have anything to copy back (by looking at `/var/lib/docker/volumes`).
Later, when I checked everything was fine, I then removed old volume.
```bash
$ docker volume rm users orgs products product_images html_data podata
```

I unmount all the previous NFS mount at system level:
```bash
$ sudo umount /mnt/{products,users,orgs,product_images}
```
and commented corresponding line in `/etc/fstab`:
```conf
# volumes are now directly mounting nfs
# 10.0.0.3:/rpool/off/clones/products           /mnt/products   nfs     rw      0 0
# 10.0.0.3:/rpool/off/clones/users              /mnt/users      nfs     rw      0 0
# 10.0.0.3:/rpool/off/clones/orgs                       /mnt/orgs       nfs     rw      0 0
# 10.0.0.3:/rpool/off/clones/images/products    /mnt/product_images     nfs     rw      0 0
```

## Refreshing clones

To refresh clones, we have to first stop docker containers on docker staging (if needed):
```bash
cd /home/off/off-net
docker-compose stop
```

On ovh3, as root, we can refresh clones, thanks to the script present there (see `scripts/ovh3/maj-clones-nfs-VM-dockers.sh`).

For each clone dataset, this:
- zfs destroy the dataset clone
- create a snapshot of the original dataset with a fixed tag depending on date
- use zfs clone to create the clone dataset again using the tag


In my case, the `sudo zfs destroy rpool/off/clones/images` failed because the system was unable to umount the dataset, which is the first step of the destroy process.
It says "volume busy" which is a classical error when you have a process still using a resource you want to umount.
I tried to bypass it using `umount -f /rpool/off/clones/images` but it failed with same errors.
I took some time trying to find the culprit process, but `lsof +D` is quite unusable due to the large amount of files.
On off staging there were no more mounted clone nfs shares (`cat /etc/mtab`).

Finally after some internet research, I stumble upon the `sudo showmount -a` command that shows which NFS shares are in use, and I found that `images` was still reported as mounted on `10.1.0.200`.
I simply did a restart of NFS services (`sudo systemctl restart nfs-server.service`) and the information was correct again, with the umount finally working.

## Restarting dockers

After recreating clones, I had to restart the dockers.

But in fact it did not happened that easily.

The boot time for dockers was very long, and it timeout.

I though this issue had been resolved by [moving VM 200 to ovh1](), to shorten latency with ovh3 and thus make NFS shares more usable. But it was still there.

By pinging ovh3 form ovh1 and from the container I saw there was not the same latency. In fact thanks to `ip route list` I realised staging docker VM was still configured to use ovh2 as the gateway instead of ovh1…

I fixed it, see [2023-04-27 moving docker staging to OVH1 / Changing route](./2023-04-27-moving-docker-stagging-to-ovh1.md#changing-route)
