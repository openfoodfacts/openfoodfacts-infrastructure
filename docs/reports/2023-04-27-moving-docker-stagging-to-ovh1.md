# 2023-04-27 moving docker staging to OVH1

See [issue #217](https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/217)

## The task

We have latency problems from ovh2 to ovh3 which makes using nfs mounts for off-net impractical.
I though we could move the datasets clones to ovh2 (#216) but it's not feasible: disks are 1T too small and the products dataset is 1,5 T (I did misread the size).

But while ovh2 is 10 ms away from ovh3, ovh1 is only 0,12 ms away (this is a 100 fold), so if we move the 200 VM to ovh1, we would be able to use nfs volumes from ovh3.

The task: move some services from ovh1 to ovh2 and move the 200 VM to ovh1.

## Proposal

Initial proposal to make the switch and keep disk space well dispatched:

* We move from ovh2 -> ovh1

  * 200 (294G) dockers-staging

* We could move ovh2 -> ovh1 (for a total of 234G !)

  * 111 (96G) wild ecoscore <-- shan't we remove instead ?
  * 120 (64G) mongo-test <-- to be removed isn't it ? YES
  * 108 (32G) folksonomy
  * 112 (42G) connect-stagging

## Doing it

I did synchronize storage of 200 on ovh1 before migration but now disk is full !

I underestimated the size (as it's a block storage, I should have considered max size (322G) instead of real size… (294G)).

Also I got a difference between what proxmox console shows on ovh1 (Usage 98.23% (940.04 GB of 956.97 G)) and `zpool list` command:
```
rpool   920G   886G  33.8G        -         -    76%    96%  1.00x    ONLINE  -
```

I did move more containers:

* 106 (51,54G) mirabelle
* 110 (45G) crm
* 103 (34G) mastodon

Still after that, monitoring was in bad shape, and also ZFS on ovh1 was too high.

So I moved monitoring VM 203 to ovh2.

Although I'm a bit sad that now monitoring is on same machine as prod dockers (200).

## Changing route

(Update on 2023-05-12)

Something was missing ! In fact we were still using the original host has gateway, thus having latency even higher !

I had to manually change the default route for VM that I moved (staging and monitoring):

* Edited `/etc/network/interfaces` to change gateway to the new host internal address (`10.0.0.x`)
* In a screen (to prevent ssh connexion loss between commands !):
  ```bash
  ip route del default via 10.0.0.2 dev ens18 onlink ; ip route add default via 10.0.0.1 dev ens18 onlink
  ```
   (or the other way around for VM 203)
