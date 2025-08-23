"""
Some filters useful in the context of proxmox
"""
from ansible.errors import AnsibleFilterError

class FilterModule:

    def filters(self):
        return {
            'proxmox_netif_dict': self.proxmox_netif_dict,
            'proxmox_netif_data_to_str': self.proxmox_netif_data_to_str,
        }

    def proxmox_netif_dict(self, data):
        return {
            key: self.proxmox_netif_data_to_str(definition)
            for key, definition in data.items()
        }

    def proxmox_netif_data_to_str(self, data):
        # see /pve-docs/api-viewer/index.html#/nodes/{node}/lxc
        netif = []
        str_attrs = [
            "name", "ip", "ip6", "bridge", "gw", "gw6", "hwaddr", "mtu", "rate", "tag", "trunks", "type"
        ]
        for key in str_attrs:
            if key in data:
                netif.append(f"{key}={data[key]}")
        bool_attrs = ["firewall", "link_down"]
        for bool_key in bool_attrs:
            if bool_key in data:
                val = "1" if data[bool_key] else "0"
                netif.append(f"{bool_key}={val}")
        return ",".join(netif)
