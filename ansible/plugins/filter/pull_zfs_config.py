"""Filters used by pull_zfs_config role."""

from typing import Any, Dict, Iterable, List, Optional

from ansible.errors import AnsibleFilterError


class FilterModule:
    """Custom filters for pull_zfs_config role."""

    _IGNORED_PROPERTY_KEYS = {
        "name",
        "pool",
        "type",
        "guid",
        "state",
        "source",
        "source_info",
        "source_code",
        "value",
    }

    def filters(self):
        return {
            "pull_zfs_config_facts_by_name": self.pull_zfs_config_facts_by_name,
        }

    @staticmethod
    def _iter_zfs_fact_entries(fact_results: Iterable[Any]) -> Iterable[Dict[str, Any]]:
        for result in fact_results or []:
            if not isinstance(result, dict):
                continue

            if "ansible_facts" in result:
                ansible_facts = result.get("ansible_facts") or {}
                if isinstance(ansible_facts, dict):
                    datasets = ansible_facts.get("ansible_zfs_datasets")
                    if isinstance(datasets, list):
                        for dataset in datasets:
                            if isinstance(dataset, dict):
                                yield dataset
                continue

            yield result

    @staticmethod
    def _property_source(property_data: Any) -> Optional[str]:
        """Extract source from a property payload returned by facts modules.

        community.general facts payloads may expose source metadata as `source`,
        `source_info`, or `source_code` depending on module/version/field shape.
        We check in that order and return the first non-empty string.
        """
        if isinstance(property_data, dict):
            for key in ("source", "source_info", "source_code"):
                source = property_data.get(key)
                if isinstance(source, str) and source:
                    return source
        return None

    @staticmethod
    def _property_value(property_data: Any) -> Optional[str]:
        """Extract a displayable value from a property payload.

        Facts modules usually return property dictionaries with `value` (and
        sometimes `raw`). We prefer `value` because it is the canonical field
        and only fall back to `raw` when needed. Non-dict payloads are treated
        as direct values.
        """
        if isinstance(property_data, dict):
            if "value" in property_data:
                value = property_data.get("value")
            else:
                value = property_data.get("raw")
        else:
            value = property_data

        if value is None:
            return None
        if isinstance(value, bool):
            return "on" if value else "off"
        return str(value)

    def pull_zfs_config_facts_by_name(
        self,
        fact_results: List[Dict[str, Any]],
        allowed_sources: Optional[List[str]] = None,
    ) -> Dict[str, Dict[str, str]]:
        """Build sorted name->properties map from zpool_facts/zfs_facts output.

        Args:
            fact_results: Either a list of `ansible_zfs_pools` dictionaries,
                or loop results containing `ansible_facts.ansible_zfs_datasets`.
            allowed_sources: Accepted property source values.

        Returns:
            Dict sorted by object name with properties sorted by key.
        """
        if allowed_sources is None:
            allowed_sources = []
        if not isinstance(allowed_sources, list) or not all(
            isinstance(source, str) for source in allowed_sources
        ):
            raise AnsibleFilterError("allowed_sources must be a list of strings")

        sources_filter = set(allowed_sources)
        grouped_properties: Dict[str, Dict[str, str]] = {}

        for entry in self._iter_zfs_fact_entries(fact_results):
            zfs_name = entry.get("name")
            if not isinstance(zfs_name, str) or not zfs_name:
                continue

            properties: Dict[str, str] = {}
            for property_name, property_data in entry.items():
                if property_name in self._IGNORED_PROPERTY_KEYS:
                    continue

                source = self._property_source(property_data)
                if sources_filter and source not in sources_filter:
                    continue

                value = self._property_value(property_data)
                if value is None:
                    continue

                properties[property_name] = value

            if properties:
                grouped_properties[zfs_name] = {
                    property_name: properties[property_name]
                    for property_name in sorted(properties)
                }

        return {
            zfs_name: grouped_properties[zfs_name]
            for zfs_name in sorted(grouped_properties)
        }
