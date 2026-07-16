"""
Filters to validate zfs dataset mount ordering across zpools.

See docs/explanation/software/virtiofs.md#inter-zpool-mounts for context:
ZFS only orders mounts within a single zpool. Datasets mounted outside
their own zpool hierarchy need org.openzfs.systemd:requires-mounts-for
to point to a parent mountpoint so systemd mounts them in the right order.
"""
from ansible.errors import AnsibleFilterError


class FilterModule:

    def filters(self):
        return {
            'zfs_validate_requires_mounts_for': self.zfs_validate_requires_mounts_for,
        }

    def zfs_validate_requires_mounts_for(self, zfs_list_stdout):
        """Validate that datasets mounted outside their own zpool hierarchy
        declare org.openzfs.systemd:requires-mounts-for pointing to a
        parent mountpoint.

        :param zfs_list_stdout: the stdout of
            ``zfs list -o name,mountpoint,org.openzfs.systemd:requires-mounts-for -H``
            (tab-separated lines: name<TAB>mountpoint<TAB>requires)
        :return: a list of human-readable error messages, one per offending
            dataset. An empty list means every dataset is compliant.
        """
        if not isinstance(zfs_list_stdout, str):
            raise AnsibleFilterError(
                "zfs_validate_requires_mounts_for expects a string "
                "(the stdout of 'zfs list ... -H')"
            )

        errors = []
        for line in zfs_list_stdout.splitlines():
            line = line.rstrip("\n")
            if not line:
                continue
            fields = line.split("\t")
            if len(fields) < 3:
                raise AnsibleFilterError(
                    f"Unexpected zfs list output, expected 3 tab-separated "
                    f"fields but got {len(fields)}: {line!r}"
                )
            name, mountpoint, requires = fields[0], fields[1], fields[2]

            # skip datasets without a usable mountpoint (volumes, legacy, none)
            if mountpoint in ("-", "none", "legacy", ""):
                continue

            # skip the case of root, it needs no parent mountpoint !
            if mountpoint == "/":
                continue

            # the natural mountpoint root of a dataset is /<pool-name>
            pool = name.split("/", 1)[0]
            natural_root = "/" + pool

            # if the mountpoint is under its own pool hierarchy, zfs already
            # orders it correctly: nothing to check.
            if mountpoint == natural_root or mountpoint.startswith(natural_root + "/"):
                continue

            # the dataset is mounted outside of its own dataset hierarchy:
            # org.openzfs.systemd:requires-mounts-for must be set.
            if requires in ("-", ""):
                errors.append(
                    f"dataset '{name}' has mountpoint '{mountpoint}' outside its pool mount hierarchy but has no "
                    f"'org.openzfs.systemd:requires-mounts-for' property set. "
                    f"Set it to a parent mountpoint, e.g.: "
                    f"zfs set org.openzfs.systemd:requires-mounts-for="
                    f"<parent-mountpoint> {name}"
                )
                continue

            # requires must point to a parent mountpoint of the dataset
            # mountpoint (strictly a parent, not the mountpoint itself).
            if mountpoint == requires:
                errors.append(
                    f"dataset '{name}' has "
                    f"'org.openzfs.systemd:requires-mounts-for={requires}' "
                    f"which equals its mountpoint '{mountpoint}' "
                    f"(must be a parent mountpoint)."
                )
            elif not (mountpoint.startswith(requires + "/")) and requires != "/":
                errors.append(
                    f"dataset '{name}' has "
                    f"'org.openzfs.systemd:requires-mounts-for={requires}' "
                    f"which is not a parent mountpoint of '{mountpoint}'. "
                    f"It must point to a parent mountpoint of the dataset."
                )

        return errors


if __name__ == "__main__":
    # tests
    mod = FilterModule()

    # empty input -> no errors
    assert mod.zfs_validate_requires_mounts_for("") == []

    # dataset under its own pool hierarchy -> ok
    assert mod.zfs_validate_requires_mounts_for(
        "rpool/ROOT\t/rpool/ROOT\t-"
    ) == []

    # dataset mounted outside its pool, with valid requires -> ok
    assert mod.zfs_validate_requires_mounts_for(
        "nvme/docker-volumes\t/hdd/docker-volumes\t/hdd"
    ) == []

    # dataset mounted outside its pool, no requires -> error
    result = mod.zfs_validate_requires_mounts_for(
        "nvme/docker-volumes\t/hdd/docker-volumes\t-"
    )
    assert len(result) == 1
    assert "nvme/docker-volumes" in result[0]

    # requires equals mountpoint -> error
    result = mod.zfs_validate_requires_mounts_for(
        "nvme/docker-volumes\t/hdd/docker-volumes\t/hdd/docker-volumes"
    )
    assert len(result) == 1
    assert "equals its mountpoint" in result[0]

    # requires not a parent -> error
    result = mod.zfs_validate_requires_mounts_for(
        "nvme/docker-volumes\t/hdd/docker-volumes\t/other"
    )
    assert len(result) == 1
    assert "not a parent mountpoint" in result[0]

    # legacy / none mountpoints are skipped
    assert mod.zfs_validate_requires_mounts_for(
        "rpool/swap\t-\t-\nnvme/vol\tnone\t-"
    ) == []

    # requires that is a prefix but not a path parent (e.g. /hdd vs /hddx)
    # must still be an error
    result = mod.zfs_validate_requires_mounts_for(
        "nvme/docker-volumes\t/hddx/data\t/hdd"
    )
    assert len(result) == 1
    assert "not a parent mountpoint" in result[0]

    print("all tests passed")
