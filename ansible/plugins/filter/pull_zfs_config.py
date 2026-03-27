"""Filters used by pull_zfs_config role."""

from typing import Any, Dict, Iterable, List, Optional

from ansible.errors import AnsibleFilterError


class FilterModule:
    """Custom filters for pull_zfs_config role."""

    def filters(self):
        return {
            "pull_zfs_config_properties_by_name": self.pull_zfs_config_properties_by_name,
        }

    @staticmethod
    def _iter_stdout_lines(command_results: Iterable[Any]) -> Iterable[str]:
        for result in command_results or []:
            if isinstance(result, dict):
                lines = result.get("stdout_lines") or []
                if isinstance(lines, list):
                    for line in lines:
                        if isinstance(line, str) and line:
                            yield line

    def pull_zfs_config_properties_by_name(
        self,
        command_results: List[Dict[str, Any]],
        allowed_sources: Optional[List[str]] = None,
    ) -> Dict[str, Dict[str, str]]:
        """Build a sorted name->properties map from zfs/zpool get output lines.

        Args:
            command_results: Loop results containing stdout_lines in
                "name\tproperty\tvalue\tsource" format.
            allowed_sources: Optional list of accepted source values.

        Returns:
            A dict sorted by ZFS object name, each containing properties sorted by key.
        """
        if allowed_sources is None:
            allowed_sources = []
        if not isinstance(allowed_sources, list) or not all(
            isinstance(source, str) for source in allowed_sources
        ):
            raise AnsibleFilterError("allowed_sources must be a list of strings")

        sources_filter = set(allowed_sources)
        grouped_properties: Dict[str, Dict[str, str]] = {}

        for line in self._iter_stdout_lines(command_results):
            fields = line.split("\t")
            if len(fields) != 4:
                raise AnsibleFilterError(
                    "unexpected zfs property line format (expected 4 tab-separated fields): "
                    f"{line}"
                )

            zfs_name, property_name, value, source = fields
            if sources_filter and source not in sources_filter:
                continue

            grouped_properties.setdefault(zfs_name, {})[property_name] = value

        sorted_grouped_properties: Dict[str, Dict[str, str]] = {}
        for zfs_name in sorted(grouped_properties):
            sorted_grouped_properties[zfs_name] = {
                property_name: grouped_properties[zfs_name][property_name]
                for property_name in sorted(grouped_properties[zfs_name])
            }

        return sorted_grouped_properties
