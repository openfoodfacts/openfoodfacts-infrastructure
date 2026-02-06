#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright (c) 2025, Alex GAREL <alex@openfoodfacts.org>
# GNU General Public License v3.0+ (see LICENSES/GPL-3.0-or-later.txt or https://www.gnu.org/licenses/gpl-3.0.txt)
# SPDX-License-Identifier: GPL-3.0-or-later
ANSIBLE_METADATA = {
    'metadata_version': '0.1',
    'status': ['preview'],
    'supported_by': 'openfoodfacts'
}



DOCUMENTATION = """
---
author:
  - Alex Garel

module: git_based_config_symlinks

short_description: check that files contained in git repository are symlinked correctly

description: |
  check that files contained in git repository are symlinked correctly
  in the context of git based config as used at Open Food Facts

options:
  src:
    description: source directory for config files
    type: str
    required: true
  dst:
    description: target directory for config files
    type: str
    required: true

attributes:
  check_mode:
    support: full
  diff_mode:
    support: none
"""

RETURN = """
    kept: symlinks kept in place
    created: created symlinks
    removed: removed symlinks
    conflicting: files already present while not pointing to right destination
"""

import os
from pathlib import Path

import ansible.module_utils.errors
from ansible.module_utils.basic import AnsibleModule
from ansible.module_utils.common.text.converters import to_native


class Result:
    def __init__(self, kept, created, removed, conflicting):
        self.kept = kept
        self.created = created
        self.removed = removed
        self.conflicting = conflicting

    def as_dict(self):
        return {
            "kept": sorted(str(p) for p in self.kept),
            "created": sorted(str(p) for p in self.created),
            "removed": sorted(str(p) for p in self.removed),
            "conflicting": sorted(str(p) for p in self.conflicting),
            "changed": bool(self.created | self.removed)
        }


# because Path.walk is only in Python3.11
# also because we want to work with relative paths
def walk_files(path):
    for dirpath, dirnames, filenames in os.walk(str(path), followlinks=True):
        yield from ((Path(dirpath) / f).relative_to(path) for f in filenames)


class GitBasedConfigSymlinks:

    def __init__(self, module):
        self.module = module
        self.src = Path(module.params['src'])
        self.dst = Path(module.params['dst'])
        self._check_parameters()

    def _check_parameters(self):
        errors = []
        if not (self.src.exists() and self.src.is_dir()):
            errors.append(f"src {self.src} is not a valid directory")
        if not (self.dst.exists() and self.dst.is_dir()):
            errors.append(f"dst {self.src} is not a valid directory")
        if errors:
            raise ansible.module_utils.errors.AnsibleValidationError("\n".join(errors))

    def compute_symlinks_state(self):
        # We work with relative file path, which makes things easy

        # Get config files to link
        git_conf_files = set(walk_files(self.src))
        # Get existing config symlinks, linking to repository
        symlinked_conf_files = set(
            filepath
            for filepath in walk_files(self.dst)
            if (
                (self.dst / filepath).is_symlink()
                and (self.dst / filepath).readlink() == (self.src / filepath)
            )
        )
        # Get eventual conflicting files
        conflicting_files = set(
            filepath
            for filepath in git_conf_files
            if (
                (self.dst / filepath).exists() and (
                    not (self.dst / filepath).is_symlink()
                    or (self.dst / filepath).readlink() != (self.src / filepath)
                )
            )
        )
        return Result(
            created=git_conf_files - symlinked_conf_files - conflicting_files,
            removed=symlinked_conf_files - git_conf_files - conflicting_files,
            kept=symlinked_conf_files & git_conf_files,
            conflicting= conflicting_files,
        )

    def run(self):
        result = self.compute_symlinks_state()
        if result.conflicting:
            self.module.fail_json(
                msg="They are conflicting files, refusing to continue",
                **result.as_dict()
            )
        else:
            if not self.module.check_mode:
                for p in result.removed:
                    p.unlink()
                for p in result.created:
                    # ensure directory
                    if not (self.dst / p.parent).exists():
                        (self.dst / p.parent).mkdir(parents=True)
                    (self.dst / p).symlink_to(self.src / p)
            self.module.exit_json(**result.as_dict())


def main():
    module = AnsibleModule(
        argument_spec=dict(
            src=dict(type='str', required=True),
            dst=dict(type='str', required=True),
        ),
        supports_check_mode=True,  # TBD
    )
    processor = GitBasedConfigSymlinks(module)
    try:
        processor.run()
    except Exception as e:
        module.fail_json(msg="An error occurred: %s" % to_native(e))


if __name__ == "__main__":
    main()