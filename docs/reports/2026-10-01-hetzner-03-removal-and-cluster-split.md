# 2029-10-01 hetzner-03 removal and proxmox cluster split

We want to decomission hetzner-03 to save money.

This will leave us with a 2 node proxmox cluster.

Instead of keeping it alive using a [`qdevice`](https://pve.proxmox.com/wiki/Cluster_Manager#_corosync_external_vote_support) as the two server are fundamentally different, I prefer to split the cluster.

So here we will remove hetzner-03 from the cluster,
then remove hetzner-01 from the cluster (hetzner-02 will be naturrally standalone)
and let hetzner-01 be standalone.

I will then fix the ansible and rerun it to insure we keep server separated.

## Spliting the cluster

See https://pve.proxmox.com/wiki/Cluster_Manager#pvecm_remove_node

I can see current nodes with:
```bash
$ pvecm nodes

Membership information
----------------------
    Nodeid      Votes Name
         1          1 hetzner-01
         2          1 hetzner-02 (local)
         3          1 hetzner-03
```

I must first remove replications:
```bash
$ pvesr list
JobID                Target                 Schedule  Rate  Enabled
202-0                local/hetzner-03           */15     -      yes
$ pvesr disable 202-0
$ pvesr delete 202-0
Replication job removal is a background task and will take some time.
$ pvesr list 
JobID                Target                 Schedule  Rate  Enabled
```

Now I shutdown `hetzner-03` using `shutdown` command in it.

When I'm sure it's down,

On `hetzner-02`:
```bash
$ pvecm delnode hetzner-03
Could not kill node (error = CS_ERR_NOT_EXIST)
Killing node 3

$pvecm nodes

Membership information
----------------------
    Nodeid      Votes Name
         1          1 hetzner-01
         2          1 hetzner-02 (local)
```

# Detaching hetzner-01

With two nodes, we will have problem if a server goes down.
Instead of having a qdevice to reach quorum,
we will isolate hetzner-01 from hetzner-02

It make sens because hetzner-01 is a pure backup server,
and thus can't really play the same role as hetzner-02.

We will follow https://pve.proxmox.com/wiki/Cluster_Manager#pvecm_separate_node_without_reinstall

On hetzner-01:

```bash
# stop corosync and pve-cluster
systemctl stop pve-cluster
systemctl stop corosync
# make pve config filesystem local
pmxcfs -l
    [main] notice: resolved node name 'hetzner-01' to '10.12.0.1' for default node IP address
    [main] notice: forcing local mode (although corosync.conf exists)
# delete corosync config
rm /etc/pve/corosync.conf
rm -r /etc/corosync/*
# You can now start the file system again as a normal service
killall pmxcfs
systemctl start pve-cluster
```

And on hetzner-02:
```bash
# remove hetzner-01 from my cluster
pvecm delnode hetzner-01
# now vote 1 is enough
pvecm expected 1
pvecm nodes

    Membership information
    ----------------------
        Nodeid      Votes Name
             2          1 hetzner-02 (local)
```

Last, on hetzner-01:
```bash
# cleanup corosync data in case we would join again the cluster later
rm /var/lib/corosync/*
```

## Changin the ansible

I did change the ansible to put `hetzner-01`
in a new `pvehetznerstore` cluster (and group)
distinct from the `hetzner-02` cluster.

I re-read all their `group_vars` and `host_vars` files.

One important variable to change is `proxmox_node__pve_cluster_enabled` to `false`,
and of course `proxmox_node__pve_cluster_name` to the *cluster* name.

I then rerun the configure job, starting with hetzner-02 where there is less risk (not much changed for it).

```bash
ansible-playbook jobs/configure.yml -l hetzner-02
ansible-playbook jobs/configure.yml -l hetzner-01
```
After the commands I did thoroughsly read the logs to verify what was changed
(and if it was consistent with what was expected).

And then, there again starting with `hetzner-02` (and verifying carefully the changes).
We don't run containers part, because there is no need here.
```bash
ansible-playbook sites/proxmox-node.yml -l hetzner-02 --skip-tags containers
# after verification
ansible-playbook sites/proxmox-node.yml -l hetzner-01 --skip-tags containers
```


## Hetzner-03 cleanup

**Important** as said by proxmox documentation,
hetzner-03 must not be turned on again as is.

But what I can do is use a recovery boot to remove all the data before uncomissioning it.

I logged into hetzner Robot interface, in server,
* click on hetzner-03
* tab "rescue"
* activate rescue system (with my ssh key), copy the root password
* tab "reset"
* *press power button on server* to boot it

Then I `ssh root@195.201.104.92` (after a `ssh-keygen -f '/home/alex/.ssh/known_hosts' -R '195.201.104.92'`)

On the server I can run a lsblk,
and shred the different partitions.
(using `screen -S shredding` to have a session that stays)

```
lsblk
# we see that big volumes ar nvme1n1p5 and nvme0n1p5
# in first session
time shred -v /dev/nvme1n1p5
# in second session
time shred -v /dev/nvme0n1p5
# in third session
for n in /dev/nvme{0,1}n1p{1..4}; do echo $n; time shred $n; done
```
The first two shred took 83m/90m in real time. 
The other where quite fast.


### stop monitoring

We must stop monitoring the hetzner-03 server.

### decomissioning hetzner-03

See https://docs.hetzner.com/general/billing-and-account-management/cancellation/cancellations-robot/


