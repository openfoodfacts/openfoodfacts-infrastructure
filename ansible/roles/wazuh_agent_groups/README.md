# wazuh_agent_groups role — centralized agent configuration as code

Owns `/etc/wazuh-manager/shared/<group>/agent.conf` for the groups listed
in `wazuh_agent_groups_config`. wazuh-ansible does not manage agent groups, hence
this role. The manager generates `merged.mg` itself and agents pull it
automatically — no manager restart is needed after a change, and groups
not listed here are left alone.

Run after `wazuh.yml`:

```bash
ansible-playbook wazuh-groups.yml -l wazuh
```

Assigning agents *to* groups stays a manager-side state change (dashboard
UI → agent groups, or `agent_groups` on the manager) and is deliberately
not part of this role.
