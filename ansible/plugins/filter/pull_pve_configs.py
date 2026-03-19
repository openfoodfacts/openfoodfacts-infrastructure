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

    def pull_pve_configs_filter_paths(self, files, exclude_regexes=None, source_dir=None):
        """Filter file entries by excluding paths matching configured regexes.

        Args:
            files: List of dictionaries returned by ansible.builtin.find.
            exclude_regexes: List of regex strings used to exclude paths.
            source_dir: Directory prefix to strip before applying regexes.

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

        if source_dir is None:
            raise AnsibleFilterError("source_dir must be provided")
        if not isinstance(source_dir, str):
            raise AnsibleFilterError("source_dir must be a string")
        normalized_source_dir = source_dir.rstrip("/")

        filtered_files = []
        for entry in files or []:
            path = entry.get("path") if isinstance(entry, dict) else None
            if not path:
                continue
            relative_path = path
            if normalized_source_dir and path.startswith(normalized_source_dir):
                relative_path = path[len(normalized_source_dir):]
                if relative_path.startswith("/"):
                    relative_path = relative_path[1:]
            if any(regex.search(relative_path) for regex in compiled_patterns):
                continue
            filtered_files.append(entry)
        return filtered_files
