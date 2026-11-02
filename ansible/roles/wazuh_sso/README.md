# wazuh_sso — Keycloak SAML SSO for Wazuh

Layers SAML authentication on top of the stack deployed by `wazuh.yml`.
wazuh-ansible has no SSO support, so this role manages only the SSO
stanzas: the vendored roles never touch them and re-runs are safe.

Run after `wazuh.yml`:

```bash
ansible-playbook wazuh-sso.yml -l wazuh
```

## Keycloak side (one-time, realm admin console)

In the existing `openfoodfacts` realm:

1. Clients → Create client: type `SAML`, client ID `wazuh-saml`.
2. Settings: name `Wazuh SSO`, `Valid redirect URIs` =
   `<dashboard-url>/*`, `IDP-Initiated SSO URL name` = `wazuh-dashboard`,
   `Name ID format` = `username`, `Force POST binding` = ON,
   `Include AuthnStatement` = ON, `Sign documents` = ON,
   `Sign assertions` = ON, `Signature algorithm` = `RSA_SHA256`,
   `SAML signature key name` = `KEY_ID`, `Canonicalization method` =
   `EXCLUSIVE`, `Front channel logout` = ON.
3. Keys: `Client signature required` = Off.
4. Advanced → Fine Grain SAML Endpoint Configuration:
   `Assertion Consumer Service POST Binding URL` =
   `<dashboard-url>/_opendistro/_security/saml/acs/idpinitiated`.
5. Realm roles: `wazuh-admins`, `wazuh-viewers`. Assign users via groups.
6. Client scopes → `role_list` → Mappers → Add by configuration → Role
   list: name `wazuhRoleKey`, `Role attribute name` = `Roles`,
   `SAML Attribute NameFormat` = Basic, `Single Role Attribute` = On.

`<dashboard-url>` is `wazuh_sso_dashboard_url` (PoC: `https://localhost:8443`
— every SSO user must forward the same local port, Keycloak matches the
redirect URI exactly).

## Verification

Private window → dashboard URL → redirect to Keycloak → login → back as
admin. `basicauth` stays enabled, so a broken IdP cannot lock anyone out.
