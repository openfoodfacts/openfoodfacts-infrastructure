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
        """Compare lxc.idmap settings to /etc/subuid or /etc/subgid.

        Each idmap entry is expected to look like ``"u 0 100000 999"`` or
        ``"g 0 100000 999"``, where the 3rd and 4th fields are the host-id
        (``start_id``) and the number of ids (``num_ids``) respectively.
        Internally, this function represents these as half-open intervals
        ``[start_id, start_id + num_ids)`` when comparing to existing entries,
        and converts them back to ``start_id`` and ``num_ids`` when generating
        lines for ``/etc/subuid`` or ``/etc/subgid``. Ranges are therefore
        treated as half-open intervals to avoid off-by-one errors.

        :param data: list of idmap settings, like "u 0 100000 999"
        :param id_type: 'u' or 'g' if we care about user or group subuid/subgid
        :param subuid_content: the content of /etc/subuid or /etc/subgid
        :param user: the user whose subuid/subgid ranges are being compared

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
            # find existing entries that overlap this expected half-open range [start_id, end_id)
            overlapping = [
                (
                    max(start_id, candidate_start_id),
                    min(end_id, candidate_end_id),
                )
                for candidate_start_id, candidate_end_id in existing_entries
                if candidate_end_id > start_id and candidate_start_id < end_id
            ]
            # if nothing overlaps, the whole expected range is missing
            if not overlapping:
                entries_to_add.append((start_id, end_id))
                continue
            # normalize and sort the overlapping segments within [start_id, end_id)
            overlapping = sorted(overlapping)
            current_start = start_id
            for covered_start, covered_end in overlapping:
                # skip empty or fully redundant segments
                if covered_end <= covered_start:
                    continue
                # any gap before this covered segment is a missing range
                if covered_start > current_start:
                    entries_to_add.append((current_start, covered_start))
                # advance the current_start to the end of the covered segment
                if covered_end > current_start:
                    current_start = covered_end
                # if we've already covered up to or beyond end_id, we can stop
                if current_start >= end_id:
                    break
            # if there is a remaining tail gap, add it as missing
            if current_start < end_id:
                entries_to_add.append((current_start, end_id))
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
