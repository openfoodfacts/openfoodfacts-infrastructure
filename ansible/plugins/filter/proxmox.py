"""
Some filters useful in the context of proxmox
"""
from ansible.errors import AnsibleFilterError

class FilterModule:

    def filters(self):
        return {
            'proxmox_netif_dict': self.proxmox_netif_dict,
            'proxmox_netif_data_to_str': self.proxmox_netif_data_to_str,
            'proxmox_process_disk_volume': self.proxmox_process_disk_volume,
        }

    def proxmox_netif_dict(self, data, current_config):
        """A filter to create netif data
        as a list of str (as requested by proxmox module)
        from a list of mappings definition

        current_config is is the proxmox_vms network attribute of the promox_vm_info result
        for this container
        """
        return {
            key: self.proxmox_netif_data_to_str(definition,  current_config)
            for key, definition in data.items()
        }

    def proxmox_netif_data_to_str(self, data,  current_config):
        """A filter to create netif str from a mapping definition
        """
        # see /pve-docs/api-viewer/index.html#/nodes/{node}/lxc
        # get hardward address from current config
        # to avoid having proxmox taking a new random one
        if "hwaddr" not in data and current_config:
            if "name" not in data:
                raise AnsibleFilterError("You must provide a name for interfaces for proxmox_netif_dict to work")
            # get the interface data
            current_if_info = [if_info for if_info in current_config if if_info["name"] == data["name"]]
            if current_if_info:
                # upper because it's less disruptive… it seems !
                data["hwaddr"] = current_if_info[0]["hwaddr"].upper()
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
        # make hwaddr predictable… otherwise it introduce unwanted changes each time
        #
        return ",".join(netif)

    def proxmox_process_disk_volume(self, data, existing=None, defaults={}):
        """A filter to transform disk volume settings,
        based upon existing configuration and defaults
        """
        result = dict(data)
        # set defaults where needed
        for key, val in defaults.items():
            if key not in result:
                result[key] = val
        # if we don't have a volume but there is an existing container,
        # use its volume name
        # This is needed because community.proxmox.proxmox
        # will break the container config in update mode
        if existing and not data.get("volume"):
            if "config" not in existing:
                raise AnsibleFilterError(
                    "You must get existing VM with config: pending to use it in proxmox_process_disk_volume"
                )
            rootfs = existing["config"]["rootfs"]
            vol_def = rootfs.split(",", 1)[0]
            storage, volume = vol_def.split(":")
            if storage == data.get("storage"):
                result["volume"] = volume
        return result
