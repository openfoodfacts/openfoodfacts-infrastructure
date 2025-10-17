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

