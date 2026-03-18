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
            'proxmox_subuid_compare': self.proxmox_subuid_compare,
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

    def proxmox_subuid_compare(self, data, id_type, subuid_content, user="root"):
        """Compare lxc.idmap settings to /etc/subuid or subgid

        :param data: list of idmap settings, like "u 0 100000 999"
        :param id_type: 'u' or 'g' if we care about user or gourp subuid
        :param subuid_content: the content of /etc/subuid or /etc/subgid

        :return: a list of lines that should be added to the file
        """
        if id_type not in ["u", "g"]:
            raise AnsibleFilterError("id_type must be 'u' or 'g'")
        expected_entries = []
        for idmap in data:
            idmap_type, _,start_id, num_ids = idmap.strip().split()
            if idmap_type == id_type:
                expected_entries.append((int(start_id), int(start_id) + int(num_ids)))
        existing_entries = [l.split(":")[1:] for l in subuid_content.split("\n") if l.startswith(user + ":")]
        existing_entries = [(int(start_id), int(start_id) + int(num_ids)) for start_id, num_ids in existing_entries]
        existing_entries.sort()
        entries_to_add = []
        for start_id, end_id in expected_entries:
            # get the existing entry overlapping
            corresponding = [
                (candidate_start_id, candidate_end_id)
                for candidate_start_id, candidate_end_id in existing_entries
                if (
                    (candidate_start_id <= start_id and candidate_end_id >= start_id)
                    or (candidate_start_id <= end_id and candidate_end_id >= end_id)
                )
            ]
            if not corresponding:
                entries_to_add.append((start_id, end_id))
            if corresponding:
                # check we don't have holes
                # note: corresponding is already sorted
                range_start, range_end = corresponding[0]
                for candidate_start_id, candidate_end_id in corresponding[1:]:
                    if candidate_start_id > range_end + 1:
                        entries_to_add.append((range_end + 1, candidate_start_id - 1))
                    range_end = max(range_end, candidate_end_id)
                if range_end < end_id + 1:
                    entries_to_add.append((range_end + 1, end_id))
        entries_to_add.sort()
        # we could remove or merge entries, won't do it for now as it's not really probable
        lines_to_add = [
            f"{user}:{start_id}:{end_id - start_id}"
            for start_id, end_id in entries_to_add
        ]
        return lines_to_add

if __name__ == "__main__":
    # test
    fmod = FilterModule()

    result = fmod.proxmox_subuid_compare(
        ["u 10 10 10", "g 10 10 10", "u 20 100 100"],
        "u",
        "root:100000:65536\nalex:165536:65536\n",
    )
    assert result == (
        ["root:10:10", "root:100:100"]
    )
    result = fmod.proxmox_subuid_compare(
        ["u 10 10 10", "g 10 10 10", "u 20 100 100"],
        "u",
        "root:0:30\nroot:100000:65536\nalex:165536:65536\n",
    )
    assert result == (
        ["root:100:100"]
    )
