# 2025-08-07 testing virtiofs


## Preparing a datasets on host

## Creating a template VM
following https://slash-root.fr/proxmox-template-debian12-avec-cloud-init/
but I will name it 999

on hetzner-02 as root:

```bash
cd /home/alex
wget https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2
apt install -y libguestfs-tools
virt-customize -a debian-12-generic-amd64.qcow2 --install qemu-guest-agent

# create the VM vmbr1 is the private bridge on hetzner-02
qm create 999 --name debian12-cloudinit --net0 virtio,bridge=vmbr1 --scsihw virtio-scsi-single
# add the disk, using rpool-pve
qm set 999 --scsi0 rpool-pve:0,iothread=1,backup=off,format=qcow2,import-from=/home/alex/debian-12-generic-amd64.qcow2
# set boot
qm set 999 --boot order=scsi0
# set some physical values
qm set 999 --cpu host --cores 2 --memory 4096
# add cloudinit
qm set  999 --ide2 local:cloudinit
# set qemu agent
qm set 999 --agent enabled=1
# make it a template
qm template 999
```

Then right click on the template in Proxmox web interface,
enables cloning. I did a full clone.

Then after that, I can set the cloudinit to have:
user: config-op
password: *****
ssh public keys: I took the content of /root/.ssh/authorized_keys on hetzner-02
IPConfig: IP: 10.12.1.200 and Gateway: 10.12.0.1

## Testing virtiofs

On the VM in hardware I added the virtiofs device, with folder id `qm-200-virtiofs`.
I enabled acl since it makes sense as we have two linux systems.

I ssh into the VM:
```bash
ssh config-op@10.12.1.200 -J alex@hetzner-02
```

Then I can mount the folder: 
```bash
sudo bash
mkdir /opt/virtiofs
mount -t virtiofs qm-200-virtiofs /opt/virtiofs
ls /opt/virtiofs
qm-200-virtiofs.txt  test
ls /opt/virtiofs/test
qm-200-virtiofs-test.txt
```

### Submounts

The point I wanted to verify is that I can have submounts.

And the test above is showing that this is ok.

I wanted to be sure though that we use virtiofs with `--announce-submounts`
because otherwise it can leads to inconsistencies for the guest system
(because Inode ID would'nt appear unique).
But proxmox automatically add this option, this can be seen in
`/usr/share/perl5/PVE/QemuServer/Virtiofs.pm`

### Access problem for non root user

After mounting the folder, config-op does not have access:

```bash
$ whoami
config-op
$ ls -l /opt/ i
total 4
drwxr-xr-x 2 root root 4096 Aug  7 16:35 virtiofs
$ ls -l /opt/virtiofs/
ls: cannot open directory '/opt/virtiofs/': Operation not supported
```

I found the solution on this [thread of proxmox forum](https://forum.proxmox.com/threads/anyone-else-having-issues-with-virtiofs-and-extended-attributes.167010/#post-787998)

We have to set `acltype` property to `posix` on the ZFS filesystem !
As this is an inherited property I only have to setit on the parent dataset.
```bash
# on hetzner-02
zfs set acltype=posixacl rpool/qm-200-virtiofs
```

I also tried to change permissions and edit a file, it all works fine.

### Some perfs measurement

Using [fio](https://linux.die.net/man/1/fio) [inspired by this SO thread](https://askubuntu.com/a/991311/72061)

```bash
sudo apt install fio
```

Testing the virtiofs folder (using a filename located there)
```bash
$ sudo fio --name TEST --eta-newline=5s --filename=/opt/virtiofs/test/fio-tempfile.dat --rw=randrw --size=500m --io_size=10g --blocksize=4k --ioengine=libaio --fsync=1 --iodepth=1 --direct=1 --numjobs=1 --runtime=60 --group_reporting
TEST: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.33
Starting 1 process
TEST: Laying out IO file (1 file / 500MiB)
Jobs: 1 (f=1): [m(1)][11.7%][r=17.3MiB/s,w=17.2MiB/s][r=4423,w=4410 IOPS][eta 00m:53s]
Jobs: 1 (f=1): [m(1)][21.7%][r=17.5MiB/s,w=17.5MiB/s][r=4470,w=4487 IOPS][eta 00m:47s] 
Jobs: 1 (f=1): [m(1)][31.7%][r=17.6MiB/s,w=17.1MiB/s][r=4494,w=4377 IOPS][eta 00m:41s] 
Jobs: 1 (f=1): [m(1)][41.7%][r=17.3MiB/s,w=17.6MiB/s][r=4425,w=4500 IOPS][eta 00m:35s] 
Jobs: 1 (f=1): [m(1)][51.7%][r=16.0MiB/s,w=16.1MiB/s][r=4104,w=4112 IOPS][eta 00m:29s] 
Jobs: 1 (f=1): [m(1)][61.7%][r=17.2MiB/s,w=16.9MiB/s][r=4408,w=4327 IOPS][eta 00m:23s] 
Jobs: 1 (f=1): [m(1)][71.7%][r=17.1MiB/s,w=16.9MiB/s][r=4378,w=4316 IOPS][eta 00m:17s] 
Jobs: 1 (f=1): [m(1)][81.7%][r=16.9MiB/s,w=17.5MiB/s][r=4333,w=4474 IOPS][eta 00m:11s] 
Jobs: 1 (f=1): [m(1)][91.7%][r=17.6MiB/s,w=17.6MiB/s][r=4499,w=4509 IOPS][eta 00m:05s] 
Jobs: 1 (f=1): [m(1)][100.0%][r=17.9MiB/s,w=17.6MiB/s][r=4582,w=4504 IOPS][eta 00m:00s]
TEST: (groupid=0, jobs=1): err= 0: pid=983: Fri Aug  8 10:12:38 2025
  read: IOPS=4495, BW=17.6MiB/s (18.4MB/s)(1054MiB/60001msec)
    slat (usec): min=2, max=282, avg=19.84, stdev=15.33
    clat (nsec): min=672, max=5918.4k, avg=29669.59, stdev=12591.65
     lat (usec): min=12, max=5923, avg=49.51, stdev=20.17
    clat percentiles (usec):
     |  1.00th=[   20],  5.00th=[   22], 10.00th=[   26], 20.00th=[   29],
     | 30.00th=[   29], 40.00th=[   30], 50.00th=[   30], 60.00th=[   30],
     | 70.00th=[   31], 80.00th=[   31], 90.00th=[   32], 95.00th=[   36],
     | 99.00th=[   48], 99.50th=[   50], 99.90th=[   59], 99.95th=[   66],
     | 99.99th=[  182]
   bw (  KiB/s): min=14912, max=24792, per=100.00%, avg=17985.82, stdev=1422.52, samples=119
   iops        : min= 3728, max= 6198, avg=4496.45, stdev=355.63, samples=119
  write: IOPS=4473, BW=17.5MiB/s (18.3MB/s)(1049MiB/60001msec); 0 zone resets
    slat (usec): min=15, max=341, avg=37.46, stdev= 3.85
    clat (nsec): min=549, max=295698, avg=31041.62, stdev=5790.96
     lat (usec): min=30, max=400, avg=68.50, stdev= 8.20
    clat percentiles (usec):
     |  1.00th=[   19],  5.00th=[   23], 10.00th=[   28], 20.00th=[   30],
     | 30.00th=[   31], 40.00th=[   31], 50.00th=[   31], 60.00th=[   32],
     | 70.00th=[   32], 80.00th=[   33], 90.00th=[   34], 95.00th=[   39],
     | 99.00th=[   51], 99.50th=[   53], 99.90th=[   64], 99.95th=[   78],
     | 99.99th=[  194]
   bw (  KiB/s): min=14920, max=24080, per=100.00%, avg=17895.53, stdev=1385.93, samples=119
   iops        : min= 3730, max= 6020, avg=4473.88, stdev=346.48, samples=119
  lat (nsec)   : 750=0.01%, 1000=0.01%
  lat (usec)   : 10=0.01%, 20=1.52%, 50=97.59%, 100=0.85%, 250=0.03%
  lat (usec)   : 500=0.01%, 750=0.01%
  lat (msec)   : 10=0.01%
  fsync/fdatasync/sync_file_range:
    sync (usec): min=25, max=17359, avg=82.62, stdev=74.56
    sync percentiles (usec):
     |  1.00th=[   43],  5.00th=[   56], 10.00th=[   59], 20.00th=[   61],
     | 30.00th=[   63], 40.00th=[   64], 50.00th=[   80], 60.00th=[   97],
     | 70.00th=[  102], 80.00th=[  104], 90.00th=[  109], 95.00th=[  113],
     | 99.00th=[  126], 99.50th=[  133], 99.90th=[  306], 99.95th=[  445],
     | 99.99th=[  553]
  cpu          : usr=2.28%, sys=17.38%, ctx=1478647, majf=0, minf=14
  IO depths    : 1=200.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=269709,268421,0,538127 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=17.6MiB/s (18.4MB/s), 17.6MiB/s-17.6MiB/s (18.4MB/s-18.4MB/s), io=1054MiB (1105MB), run=60001-60001msec
  WRITE: bw=17.5MiB/s (18.3MB/s), 17.5MiB/s-17.5MiB/s (18.3MB/s-18.3MB/s), io=1049MiB (1099MB), run=60001-60001msec

$ sudo rm /opt/virtiofs/test/fio-tempfile.dat
```

Comparing to zfs volume:

```bash
$ sudo fio --name TEST --eta-newline=5s --filename=/root/fio-tempfile.dat --rw=randrw --size=500m --io_size=10g --blocksize=4k --ioengine=libaio --fsync=1 --iodepth=1 --direct=1 --numjobs=1 --runtime=60 --group_reporting
TEST: (g=0): rw=randrw, bs=(R) 4096B-4096B, (W) 4096B-4096B, (T) 4096B-4096B, ioengine=libaio, iodepth=1
fio-3.33
Starting 1 process
TEST: Laying out IO file (1 file / 500MiB)
Jobs: 1 (f=1): [m(1)][11.5%][r=16.7MiB/s,w=16.6MiB/s][r=4278,w=4241 IOPS][eta 00m:54s]
Jobs: 1 (f=1): [m(1)][21.3%][r=16.3MiB/s,w=16.6MiB/s][r=4169,w=4240 IOPS][eta 00m:48s] 
Jobs: 1 (f=1): [m(1)][31.1%][r=17.0MiB/s,w=16.7MiB/s][r=4364,w=4278 IOPS][eta 00m:42s] 
Jobs: 1 (f=1): [m(1)][41.0%][r=17.5MiB/s,w=17.1MiB/s][r=4480,w=4365 IOPS][eta 00m:36s] 
Jobs: 1 (f=1): [m(1)][50.8%][r=17.4MiB/s,w=16.7MiB/s][r=4448,w=4277 IOPS][eta 00m:30s] 
Jobs: 1 (f=1): [m(1)][60.7%][r=16.9MiB/s,w=17.0MiB/s][r=4320,w=4353 IOPS][eta 00m:24s] 
Jobs: 1 (f=1): [m(1)][70.5%][r=16.9MiB/s,w=17.3MiB/s][r=4319,w=4417 IOPS][eta 00m:18s] 
Jobs: 1 (f=1): [m(1)][80.3%][r=17.0MiB/s,w=17.1MiB/s][r=4345,w=4372 IOPS][eta 00m:12s] 
Jobs: 1 (f=1): [m(1)][90.2%][r=17.5MiB/s,w=17.1MiB/s][r=4475,w=4379 IOPS][eta 00m:06s] 
Jobs: 1 (f=1): [m(1)][100.0%][r=17.3MiB/s,w=17.2MiB/s][r=4418,w=4402 IOPS][eta 00m:00s]
TEST: (groupid=0, jobs=1): err= 0: pid=993: Fri Aug  8 10:14:22 2025
  read: IOPS=4311, BW=16.8MiB/s (17.7MB/s)(1010MiB/60001msec)
    slat (nsec): min=3239, max=182421, avg=4854.38, stdev=962.24
    clat (nsec): min=467, max=283200, avg=40160.84, stdev=3875.56
     lat (usec): min=29, max=324, avg=45.02, stdev= 4.07
    clat percentiles (usec):
     |  1.00th=[   34],  5.00th=[   36], 10.00th=[   37], 20.00th=[   38],
     | 30.00th=[   39], 40.00th=[   39], 50.00th=[   40], 60.00th=[   41],
     | 70.00th=[   42], 80.00th=[   43], 90.00th=[   45], 95.00th=[   47],
     | 99.00th=[   50], 99.50th=[   52], 99.90th=[   67], 99.95th=[   79],
     | 99.99th=[  135]
   bw (  KiB/s): min=14688, max=18984, per=100.00%, avg=17251.56, stdev=637.83, samples=119
   iops        : min= 3672, max= 4746, avg=4312.89, stdev=159.46, samples=119
  write: IOPS=4291, BW=16.8MiB/s (17.6MB/s)(1006MiB/60001msec); 0 zone resets
    slat (usec): min=3, max=181, avg= 5.10, stdev= 1.01
    clat (nsec): min=560, max=301217, avg=43405.84, stdev=4247.83
     lat (usec): min=29, max=311, avg=48.51, stdev= 4.54
    clat percentiles (usec):
     |  1.00th=[   37],  5.00th=[   39], 10.00th=[   40], 20.00th=[   41],
     | 30.00th=[   42], 40.00th=[   42], 50.00th=[   43], 60.00th=[   44],
     | 70.00th=[   45], 80.00th=[   47], 90.00th=[   49], 95.00th=[   50],
     | 99.00th=[   54], 99.50th=[   59], 99.90th=[   77], 99.95th=[   88],
     | 99.99th=[  135]
   bw (  KiB/s): min=14720, max=18104, per=99.99%, avg=17163.90, stdev=571.15, samples=119
   iops        : min= 3680, max= 4526, avg=4290.97, stdev=142.79, samples=119
  lat (nsec)   : 500=0.01%, 750=0.01%, 1000=0.01%
  lat (usec)   : 2=0.01%, 4=0.01%, 50=97.45%, 100=2.52%, 250=0.02%
  lat (usec)   : 500=0.01%
  fsync/fdatasync/sync_file_range:
    sync (usec): min=21, max=17239, avg=110.97, stdev=101.78
    sync percentiles (usec):
     |  1.00th=[   58],  5.00th=[   62], 10.00th=[   63], 20.00th=[   65],
     | 30.00th=[   68], 40.00th=[   71], 50.00th=[  118], 60.00th=[  124],
     | 70.00th=[  127], 80.00th=[  131], 90.00th=[  139], 95.00th=[  314],
     | 99.00th=[  347], 99.50th=[  355], 99.90th=[  392], 99.95th=[  490],
     | 99.99th=[  635]
  cpu          : usr=2.22%, sys=9.65%, ctx=1518489, majf=0, minf=15
  IO depths    : 1=200.0%, 2=0.0%, 4=0.0%, 8=0.0%, 16=0.0%, 32=0.0%, >=64=0.0%
     submit    : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     complete  : 0=0.0%, 4=100.0%, 8=0.0%, 16=0.0%, 32=0.0%, 64=0.0%, >=64=0.0%
     issued rwts: total=258665,257474,0,516136 short=0,0,0,0 dropped=0,0,0,0
     latency   : target=0, window=0, percentile=100.00%, depth=1

Run status group 0 (all jobs):
   READ: bw=16.8MiB/s (17.7MB/s), 16.8MiB/s-16.8MiB/s (17.7MB/s-17.7MB/s), io=1010MiB (1059MB), run=60001-60001msec
  WRITE: bw=16.8MiB/s (17.6MB/s), 16.8MiB/s-16.8MiB/s (17.6MB/s-17.6MB/s), io=1006MiB (1055MB), run=60001-60001msec

Disk stats (read/write):
  sda: ios=258488/802964, merge=0/29895, ticks=10427/43539, in_queue=83515, util=81.65%

$ sudo rm /root/fio-tempfile.dat
```

We have comparable results on both.