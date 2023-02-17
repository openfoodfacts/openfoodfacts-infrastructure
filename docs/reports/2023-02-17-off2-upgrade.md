# 2023-02-17 Off2 Upgrade

## Hardware

We plug a monitor and a keyboard on off2 (on the rear).
We shut down the server. And remove both plugs.


Then we removed the two 4Tb disks (they were on the right). We unscrew them from the rail, and put the new 14Tb disks. We now have 4x14Tb.
The new 14Tb disks have exactly the same reference numbers as the old one.

Then we put the new RAMs in the server. They are symmetric to the already existing one, on the other side of the CPU. The cover indicates in which orientation memories should be connected.

We removed the card with the two SSDs on it to put a new card that support four SSD. We removed the box containing the card from the back of the server (next to ethernet ports) and plug the card out. The new card is a bit bigger than the previous so we have to remove a small piece of plastic to pull it into place. But first we put the three SSDs + the Optane disk (two on each sides). We miss one small screw for on of the SSD, but as it is blocked by the box bottom, it's not a problem.
We put the card back into the server.

**FIXME photos**

Now we are ready for reboot.

We plug the server again.

We put the bootable USB stick with [Proxmox VE](https://www.proxmox.com/en/proxmox-ve) iso for installation.

We power on (small button on the right on the front of the server).

## Bios config

At some point, after memory check, the server display a dark screen and indicates some key to trigger BIOS. We hit F2 to enter BIOS (System Setup).

We go in:
* System BIOS
* Integrated devices
* Slot bifurcation
* we choose: Auto discovery of bifurcation

This is to specify how the PCI card supporting SSD will work (16 port divided in 4x4).

We go in Network settings to configure IPMI:
* disable DHCP and auto-discovery
* Static IP address: 213.36.253.209
* Gateway: 213.36.253.222
* Subnet Mask: 255.255.255.224
* Static DNS: 213.36.253.10
* Static Alter: **FIXME** (see photo)



## Proxmox install

