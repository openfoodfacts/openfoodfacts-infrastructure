# 2024-02-28 proxmox roles search

I search for Ansible Galaxy for interesting roles/plugins for Proxmox.

Here is what I found in collections:

* [sbarbett.proxmox_management](https://galaxy.ansible.com/ui/repo/published/sbarbett/proxmox_management) has various roles that might be interesting to setup VM/CT (license MIT)
* [cloudcodger.proxmox_openssh](https://galaxy.ansible.com/ui/repo/published/cloudcodger/proxmox_openssh) also has various roles and some plugins to install hosts, it seems well architected (GPL-2.0-or-later)
* [maxhoesel.proxmox](https://galaxy.ansible.com/ui/repo/published/maxhoesel/proxmox) also seems really well done and covers a lot of aspects,
  but it didn't receive updates since a long time (GPL-3.0-or-later)
* [nfaction.boostrap](https://galaxy.ansible.com/ui/repo/published/nfaction/boostrap) has a role to setup a Proxmox node (GPL-2.0-or-later)


The ansible collection [Community.General](https://docs.ansible.com/ansible/latest/collections/community/general/) has a lot of proxmox plugins.

I then search for roles (sorted by download count):
* I saw enix has it's own role: https://github.com/enix/ansible-proxmox-ve (GPLv2)
  I know their competence but they say this role is a bit tailored to their specific needs.
  (also they say it's configurable)
  It might also be of inspiration.
* [tobias_richter.proxmox](https://galaxy.ansible.com/ui/standalone/roles/tobias_richter/proxmox/) seems good but does a lot of things than I'm not sure we need
* [lae.proxmox](https://galaxy.ansible.com/ui/standalone/roles/lae/proxmox/) seems to do all the base config we need (MIT)

I think lae.proxmox is the most interesting one.

