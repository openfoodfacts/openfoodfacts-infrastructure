# Free Datacenter

[Fondation Free](https://www.fondation-free.fr/) is graciously providing us hosting for two servers: off1 and off2.
They also provide network and electricity for free.

## Location

Those servers are located is Bezon, near Paris. To go there we need to ask to the team there.

The two servers are piled one above another (off2 on top).
It's a bay with different Open Source projects' servers.
They have at small label on them "Open Food Facts"


## Servers

Those are DELL servers.

On the back side of server cover you find some useful instructions.

<img src="img/2023-02-free-dc-instructions-on-server-cover.jpg" height="250px" alt="Server cover" title="Instructions on the server cover">


To switch a server off, plug a screen and keyboard or use ssh, login and use shutdown command.

The server switch on button is on the front panel, a small ⏼ button on the right.

There is a double plug for power supply. A small velcro helps keeps plugs in place.


<img src="img/2023-02-free-dc-plugs-velcro.jpg" height="250px" alt="Plugs velcro" title="A small velcro maintains plugs in place">

There is a blue led if all is ok (on the front and on the back). If something is wrong it turns to orange and blinks. (it will be the case for example if cover is not on the server).

You can make the LED blink to identify the server by a button on the left on the front side of the server.

## IPMI

IPMI enables rebooting the server through the network.

Connecting to 213.36.253.209 with a browser or ssh we get access to an emergency console on the machine.

(**FIXME** c'est safe que ce ne soit pas plus protégé que ça (pour un accès par mot de passe en plus ? Quel mot de passe ?))

It has to be configured with the right static network configuration in BIOS to be able to work (see below)

## Network

We have three network physical interface on each server:
- one dedicated to ipmi
- one for internal network - on a dedicated small switch between OFF and OSM machines
- one for public network

<img src="img/2023-02-free-dc-ethernet.jpg" height="250px" alt="Ethernet cables" title="The three eternet cables on the server">


## Disks

SATA Disks are on the front panel. You just have to push a small red button, it makes a small handle comes out and you can rack them out.

We had to use Dell SATA disks because otherwise there maybe compatibility issues (this is one of the limitation of DELL servers).

SSDs are in the back of the server (extension card)


## off2 configuration

off2.openfoodfacts.org

- 4x14Tb disks
- 2x2TB SSD
- 1x1TB SSD
- 1x60GB [optane disk](https://en.wikipedia.org/wiki/3D_XPoint)

Optane disk are as fast as flash drives but without being sensitive to rewrites (no limited life).

The 14Tb disks are in a ZFS pool mounted as RAID 1 (rpool)

Since Feb. 2023, off2 uses [Proxmox](./promox.md).


### BIOS settings

#### Slot bifurcation

This is to specify how the PCI card supporting SSD will work (16 port divided in 4x4).

In System BIOS / Integrated devices / Slot bifurcation: *Auto discovery of bifurcation*

#### PERC adapter

PERC Adapter Bios (Power Edge RAID Controller) is set to be  *HBA mode* for we use ZFS and don't want system RAID.


#### IDRAC / IPMI settings

Those settings are in the BIOS settings.
They enable a distant reboot of the server through a specific interface.

* disable DHCP and auto-discovery
* Static IP address: 213.36.253.209
* Gateway: 213.36.253.222
* Subnet Mask: 255.255.255.224
* Static DNS: 213.36.253.10
* Static Alter: 213.36.252.131
