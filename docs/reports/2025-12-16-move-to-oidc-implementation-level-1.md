# 2025-10-17 Move Production Services to OIDC Implementation level 1

For each service:

* OBF
* OPFF
* OPF
* OFF-PRO
* OFF

Edit Config2.pm and set `$oidc_implementation_level = 1;`

Restart services with:

```
sudo systemctl stop apache2 cloud_vision_ocr@$SERVICE.service minion@$SERVICE.service; sudo systemctl start apache2 cloud_vision_ocr@$SERVICE.service minion@$SERVICE.service
```

Log in to each platform, go to Account Parameters and edit my user name and verify that this is reflected in [Keycloak](https://auth.openfoodfacts.org/admin/master/console/#/openfoodfacts/users/04399f5e-e791-4e3d-8ae2-ff789ac2d0d0/settings)

## 17:12 GMT Status

Found that auth.openfoodfacts.org was down when starting so manually restarted

When working on OFF the oidc settings were not present at all so had to add.

Had to revert as auth.openfoodfacts.org went down again. Need to investigate why...

## Resumed on 2025-12-16

Server has now moved to Scaleway so Config2.pm needs to read:

```
$oidc_implementation_level = 1;
$oidc_discovery_url = 'https://auth.openfoodfacts.org/realms/openfoodfacts/.well-known/openid-configuration';
```

Progress:

* OBF: Done
* OPFF: Done
* OPF: Done
* OFF-PRO: Done
* OFF: Done

Running migration script `perl scripts/migrate_users_to_keycloak.pl` on OFF:

[Tue Dec 16 12:41:04 2025] Started
[Tue Dec 16 12:47:33 2025] Validated 10000 / 380436
[Tue Dec 16 13:34:02 2025] Validated 50000 / 380436
broken pipe

Resumed using `screen -S keycloak-import`

[Tue Dec 16 16:00:03 2025] Starting email validation
[Tue Dec 16 16:05:53 2025] Validated 10000 / 380457
[Tue Dec 16 21:08:29 2025] Validated 380457 / 380457
[Tue Dec 16 21:41:02 2025] Migrated 10000 / 376346
[Wed Dec 17 07:01:29 2025] Migrated 200000 / 376346
[Wed Dec 17 09:33:31 2025] Migrated 250000 / 376346
[Wed Dec 17 12:14:45 2025] Migrated 300000 / 376346
[Wed Dec 17 16:50:42 2025] Migrated 376346 / 376346

