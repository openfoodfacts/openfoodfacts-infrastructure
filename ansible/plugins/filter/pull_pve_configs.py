"""
Filters used by pull_pve_configs role
"""

import re
from typing import Any, Dict, List, Optional
from ansible.errors import AnsibleFilterError


class FilterModule:
    """Custom filters for the pull_pve_configs role."""

    _COROSYNC_NODE_NAME_PATTERN = re.compile(r"^name\s*:\s*([^\s#:]+)(?:\s|$)")

    @staticmethod
    def _line_without_comment(line: str) -> str:
        return line.partition("#")[0].strip()

    @staticmethod
    def _brace_delta(line: str) -> int:
        return line.count("{") - line.count("}")

    @staticmethod
    def _is_inactive_node_path(relative_path: str, active_nodes_set: set) -> bool:
        """Return True only for nodes/<name>/... paths not present in active_nodes_set.

        If active_nodes_set is empty, this returns False so no node path is dropped.
        """
        relative_path_parts = relative_path.split("/")
        return (
            len(relative_path_parts) > 1
            and relative_path_parts[0] == "nodes"
            and active_nodes_set
            and relative_path_parts[1] not in active_nodes_set
        )

    def filters(self):
        return {
            "pull_pve_configs_filter_paths": self.pull_pve_configs_filter_paths,
            "pull_pve_configs_extract_active_nodes": self.pull_pve_configs_extract_active_nodes,
        }

    def pull_pve_configs_filter_paths(
        self,
        files: List[Dict[str, Any]],
        exclude_regexes: Optional[List[str]] = None,
        source_dir: Optional[str] = None,
        active_nodes: Optional[List[str]] = None,
    ) -> List[Dict[str, Any]]:
        """Filter file entries by excluding paths matching configured regexes.

        Args:
            files: List of dictionaries returned by ansible.builtin.find.
            exclude_regexes: List of regex strings used to exclude paths.
            source_dir: Directory prefix to strip before applying regexes.
            active_nodes: List of active node names allowed under nodes/.

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

        if active_nodes is None:
            active_nodes = []
        if not isinstance(active_nodes, list):
            raise AnsibleFilterError("active_nodes must be a list")
        if not all(isinstance(node, str) for node in active_nodes):
            raise AnsibleFilterError("each active node must be a string")
        active_nodes_set = set(active_nodes)

        filtered_files = []
        for entry in files or []:
            path = entry.get("path") if isinstance(entry, dict) else None
            if not path:
                continue
            relative_path = path
            if path.startswith(normalized_source_dir):
                relative_path = path[len(normalized_source_dir):]
                if relative_path.startswith("/"):
                    relative_path = relative_path[1:]
            if self._is_inactive_node_path(relative_path, active_nodes_set):
                continue
            if any(regex.search(relative_path) for regex in compiled_patterns):
                continue
            filtered_files.append(entry)
        return filtered_files

    def pull_pve_configs_extract_active_nodes(self, corosync_conf_content: str) -> List[str]:
        """Extract active node names from corosync.conf content.

        Args:
            corosync_conf_content: Full text content of /etc/pve/corosync.conf.

        Returns:
            List of node names declared inside nodelist node blocks.
            Assumes node names are hostname-like tokens without spaces or ":".

        Raises:
            AnsibleFilterError: If input content type is invalid.
        """
        if not isinstance(corosync_conf_content, str):
            raise AnsibleFilterError("corosync_conf_content must be a string")

        in_nodelist = False
        awaiting_nodelist_brace = False
        nodelist_depth = 0
        active_nodes = []

        for raw_line in corosync_conf_content.splitlines():
            line = self._line_without_comment(raw_line)
            if not line:
                continue

            line_brace_delta = self._brace_delta(line)
            current_line_starts_nodelist = False

            if not in_nodelist and re.match(r"^nodelist(?:\s|{|$)", line):
                current_line_starts_nodelist = True
                # nodelist_depth > 0 means opening "{" is on this line, otherwise it's on a following line.
                nodelist_depth = line_brace_delta
                in_nodelist = nodelist_depth > 0
                awaiting_nodelist_brace = nodelist_depth <= 0

            if awaiting_nodelist_brace and not current_line_starts_nodelist:
                nodelist_depth += line_brace_delta
                if nodelist_depth > 0:
                    in_nodelist = True
                    awaiting_nodelist_brace = False
                continue

            if in_nodelist:
                # Capture hostname-like node names (no whitespace, # comments, or : separator).
                name_match = self._COROSYNC_NODE_NAME_PATTERN.match(line)
                if name_match:
                    active_nodes.append(name_match.group(1))
                if not current_line_starts_nodelist:
                    nodelist_depth += line_brace_delta
                if nodelist_depth <= 0:
                    in_nodelist = False
                    awaiting_nodelist_brace = False
                    nodelist_depth = 0

        return active_nodes
