# 2023-12-18 off1 upgrade

This is the same operation as [# 2023-02-17 Off2 Upgrade](./2023-02-17-off2-upgrade.md)
but for off1.

We will:
* add four 14T disks
* add an adapter card for SSD
* add two 2T nvme disk and one 14G optane, while keeping existing nvme
* completely reinstall the system with Proxmox 7.4.1
  * rpool in mirror-0 for the system
    * using a 70Gb part on all hdd disks
  * zfs-hdd in raidz1-0 for the data
    * using a 14T-70G par on all hdd disks
  * zfs-nvme in raidz1-0 for data that needs to be fast
    * using the two 2T nvme
    * using 8G part on octane for logs



