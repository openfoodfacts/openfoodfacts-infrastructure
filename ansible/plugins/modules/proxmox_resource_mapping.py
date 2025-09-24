#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
IMPORTANT NOTE: this file is heavily
copied on lae/ansible-role-proxmox (library/proxmox_metric_server.py)
and thus should follow same license.
"""

ANSIBLE_METADATA = {
    "metadata_version": "0.1",
    "status": ["preview"],
    "supported_by": "",
}

DOCUMENTATION = """
---
module: proxmox_resource_mapping
short_description: Manages the Resource Mapping in Proxmox
description: Manages the Resource Mapping in Proxmox
options:
    type:
        required: true
        type: str
        choices: ["pci", "usb", "dir"]
        description:
            - type of mapping
    id:
        required: true
        type: str
        description:
            - Id of the item
    map:
        required: true
        type: list
        description:
            - The mappings definitions
    description:
        type: str
        description:
            - an optional description of the mapping
    state:
        type: str
        default: "present"
        choices: [ "present", "absent" ]
        description:
            - Whether the mapping should exist or not.

author:
    - AlexGarel
    - ThysTips (@thystips)
"""

EXAMPLES = """
- name: Add a directory mapping
  proxmox_resource_mapping:
    type: dir
    id: "qm201-virtiofs"
    map:
      - "node=node1,path=/path/to/share1"
"""

RETURN = """
"""
import sys

from ansible.module_utils.basic import AnsibleModule  # noqa: E402
from ansible.module_utils.pvesh import ProxmoxShellError  # type: ignore # noqa: E402
# use our modified version of lae.proxmox.pvesh
# FIXME: submit a path to upstream repository
import ansible.module_utils.pvesh_ as pvesh  # type: ignore # noqa: E402


class ProxmoxResourceMapping(object):
    """Resource Mapping Handler

    Note: we use pvesh, which is a proxy to the API.
    Mapping API documentation is at https://pve.proxmox.com/pve-docs/api-viewer/index.html#/cluster/mapping
    """

    def __init__(self, module):
        self.module = module
        self.type = module.params["type"]
        self.id = module.params["id"]
        self.map = module.params["map"]
        self.description = module.params["description"].strip()
        self.state = module.params["state"]

        self.existing_mappings = self.get_existing_mappings()

    def _mapping_data(self, mapping_info):
        """Only get the data part of the mapping

        As with `pvesh get` we also get additional info, like type, id and digest
        """
        return {
            k: v
            for k, v in mapping_info.items()
            if k not in ("type", "id", "digest")
        }

    def get_existing_mappings(self):
        """
        Get current mappings information
        return a dict of mapping information indexed by (type,id)
        """
        try:
            mappings_info = pvesh.get(f"cluster/mapping/{self.type}")
        except pvesh.ProxmoxShellError as e:
            self.module.fail_json(msg=e.message, status_code=e.status_code)
        return {
            (info["type"], info["id"]): self._mapping_data(info)
            for info in mappings_info
        }

    def exists(self):
        return (self.type, self.id) in self.existing_mappings

    def prepare_mapping_args(self, create=True):
        args = {"map": self.map}
        if self.description:
            args["description"] = self.description
        return args

    def remove_mapping(self):
        try:
            pvesh.delete(f"cluster/mapping/{self.type}/{self.id}")
            return (True, None)
        except pvesh.ProxmoxShellError as e:
            return (False, e.message)

    def create_mapping(self):
        new_mapping = self.prepare_mapping_args()

        try:
            pvesh.create(f"cluster/mapping/{self.type}", id=self.id, **new_mapping)
            return (True, None)
        except pvesh.ProxmoxShellError as e:
            return (False, e.message)

    def modify_mapping(self):
        current_mapping = self.existing_mappings[(self.type, self.id)]
        new_mapping = self.prepare_mapping_args(create=False)
        updated_fields = []
        error = None

        for key in new_mapping:
            if key not in current_mapping:  # type: ignore
                updated_fields.append(key)
            else:
                new_value = new_mapping.get(key)
                old_value = current_mapping.get(key)  # type: ignore
                if isinstance(old_value, list):
                    old_value = ",".join(sorted(old_value))
                if isinstance(new_value, list):
                    new_value = ",".join(sorted(new_value))

                if new_value != old_value:
                    updated_fields.append(key)

        removed_keys = set(current_mapping.keys()) - set(new_mapping.keys())
        # only account for key with a value
        updated_fields.extend(key for key in removed_keys if current_mapping.get(key))

        if self.module.check_mode:
            self.module.exit_json(
                changed=bool(updated_fields), expected_changes=updated_fields
            )

        if not updated_fields:
            # No changes necessary
            return (updated_fields, error)

        try:
            # there is no update (POST) operation on this API
            pvesh.set(f"cluster/mapping/{self.type}/{self.id}", **new_mapping)
        except pvesh.ProxmoxShellError as e:
            error = e.message

        return (updated_fields, error)


def main():
    # Refer to https://pve.proxmox.com/pve-docs/api-viewer/index.html#/cluster/mapping
    module_args = dict(
        type=dict(type="str", required=True, choices=["pci", "usb", "dir"]),
        id=dict(type="str", required=True),
        map=dict(type="list", required=True),
        description=dict(default="", type="str"),
        state=dict(default="present", choices=["present", "absent"], type="str"),
    )

    module = AnsibleModule(
        argument_spec=module_args,
        supports_check_mode=True,
    )

    resource_mapping = ProxmoxResourceMapping(module)

    changed = False
    error = None
    result = {
        "type": resource_mapping.type,
        "id": resource_mapping.id,
        "state": resource_mapping.state,
        "changed": False,
    }
    if resource_mapping.state == "absent":
        if resource_mapping.exists():
            if module.check_mode:
                module.exit_json(changed=True)

            (changed, error) = resource_mapping.remove_mapping()
    elif resource_mapping.state == "present":
        if not resource_mapping.exists():
            if module.check_mode:
                module.exit_json(changed=True)

            (changed, error) = resource_mapping.create_mapping()
        else:
            (updated_fields, error) = resource_mapping.modify_mapping()

            if updated_fields:
                changed = True
                result["updated_fields"] = updated_fields

    if error is not None:
        module.fail_json(name=f"{resource_mapping.type}/{resource_mapping.id}", msg=error)

    result["changed"] = changed
    module.exit_json(**result)


if __name__ == "__main__":
    main()