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

    def proxmox_ipconfig_dict(self, data):
        """A filter to create ipconfig data
        as a list of str (as requested by proxmox module)
        """
        return {
            ipconfign: ",".join(
                f"{key}={definition}"
                for key, definition in sorted(ipdef.items())
            )
            for ipconfign, ipdef in data.items()
        }

    def proxmox_net_dict(self, data, current_config):
        """A filter to create net data
        as a list of str (as requested by proxmox module)
        from a list of mappings definition

        current_config is is the proxmox_vms config attribute of the promox_vm_info result
        for this container
        """
        return {
            key: self.proxmox_net_data_to_str(definition, key, current_config)
            for key, definition in data.items()
        }

    def proxmox_net_data_to_str(self, data, net_key, current_config):
        """A filter to create net str from a mapping definition
        """
        # normalize model=macaddr style
        models = ["e1000", "e1000-82540em", "e1000-82544gc", "e1000-82545em", "i82551", "i82557b", "i82559er", "ne2k_isa", "ne2k_pci", "pcnet", "rtl8139", "virtio", "vmxnet3"]
        model_key = list(set(data.keys()) & set(models))
        if model_key:
            if len(model_key) > 1:
                raise AnsibleFilterError("Expected only one model key, got %r", model_key)
            data["model"] = model_key[0]
            data["macaddr"] = data.pop(model_key[0])
        # see /pve-docs/api-viewer/index.html#/nodes/{node}/qemu
        # get model MAC from current config
        # to avoid having proxmox taking a new random one
        if "macaddr" not in data and current_config:
            # get the interface data
            current_if_info = current_config.get(net_key)
            if current_if_info:
                # grep the macaddress inside using a regexp, because it's the simplest way
                mac_match = re.search(r"=(?P<macaddr>[([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2})(,|$)", current_if_info) 
                if mac_match:
                    data["macaddr"] = mac_match.group("macaddr")
        netif = []
        str_attrs = [
            "model", "bridge", "macaddr", "mtu", "queues", "rate", "tag", "trunks",
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
