# 2024-02-06 cleanup of products ssnapshots on off2

It's been a while since we migrated off products to off2.

Previous snapshot system did not use sanoid. So there are several old snapshot that we should remove.

We can see snapshots with
```
zfs list  -r zfs-nvme/off/products -t snap -o name|grep -v autosnap
```

I see the old snapshots that looks like `@20231122-1906`.
I want to keep one snapshot per month, but I will rename it to look like a sanoid snapshot. (so sanoid will clean it according to retention policy).

doing it manually it looks like this kind of command:
```bash
zfs rename zfs-nvme/off/products@20231101-0000 zfs-nvme/off/products@autosnap_2023-11-01_00:00:00_monthly
```

or more automatic (on off-pro products):
```bash
# remove the echo in front of zfs rename when you have tested it
for m in 0{5..9} 1{0,1};do echo zfs rename zfs-nvme/off-pro/products@2023${m}01-0000 autosnap_2023-${m}-01_00:00:00_monthly; done
```

Then I remove the old snapshots:
```bash
# remove the echo in front off zfs destroy when you have tested it
for f in $(zfs list  -r zfs-nvme/off/products -t snap -o name);do [[ $f == *"@2023"* ]] && echo $f && echo zfs destroy $f;done
```

I did it for off, off-pro, opf, opff and obf.

I then disable snapshot_purge from crontab.