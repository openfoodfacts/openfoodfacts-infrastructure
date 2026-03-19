"""
Filters used by pull_pve_configs role
"""

import re
from ansible.errors import AnsibleFilterError


class FilterModule:
    """Custom filters for the pull_pve_configs role."""

    def filters(self):
        return {
            "pull_pve_configs_filter_paths": self.pull_pve_configs_filter_paths,
        }

    def pull_pve_configs_filter_paths(self, files, exclude_regexes=None):
        """Filter file entries by excluding paths matching configured regexes.

        Args:
            files: List of dictionaries returned by ansible.builtin.find.
            exclude_regexes: List of regex strings used to exclude paths.

        Returns:
            A filtered list of file dictionaries.

        Raises:
            AnsibleFilterError: If regex inputs are not valid.
        """
        if exclude_regexes is None:
            exclude_regexes = []

        if not isinstance(exclude_regexes, list):
            raise AnsibleFilterError("exclude_regexes must be a list of regex patterns")

        compiled_patterns = []
        for pattern in exclude_regexes:
            if not isinstance(pattern, str):
                raise AnsibleFilterError("each exclude regex must be a string")
            try:
                compiled_patterns.append(re.compile(pattern))
            except re.error as exc:
                raise AnsibleFilterError(f"invalid regex pattern '{pattern}': {exc}") from exc

        filtered_files = []
        for entry in files or []:
            path = entry.get("path") if isinstance(entry, dict) else None
            if not path:
                continue
            if any(regex.search(path) for regex in compiled_patterns):
                continue
            filtered_files.append(entry)
        return filtered_files
