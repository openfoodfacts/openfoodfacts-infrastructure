# Setup of Odoo for pro platform

## installing rest-framework

Following [our odoo documentation](../odoo.md#contributed-modules-from-oca-store)

And finally I may not need this… as it is intended as a framework 
Et en fait … j'en ai pas vraiment besoin car c'est pour dev des modèles spécifiques dans odoo (ce que je veux éviter pour le moment).

## Adding specific fields


## making an api key

Following : https://www.odoo.com/documentation/master/developer/api/external_api.html#

- preferences - account security - new api key
- there is no ACL for key so we need a specific user to the app to avoid giving too much privileges

## getting database name

I used https://connect-test.openfoodfacts.org/web/database/manager (there may be a better way)

It's also written next to the user name in the web interface !

It's `crm`

## testing

```bash
docker-compose run --rm --no-deps --user=root  backend bash
cpanm XML::RPC
re.pl
```

```perl
$ use XML::RPC;
$ my $xmlrpc = XML::RPC->new('https://connect-test.openfoodfacts.org//xmlrpc/2/common');
$XML_RPC1 = XML::RPC=HASH(0x556034d3c498);
$ $xmlrpc->call( 'version');
$HASH1 = {
           protocol_version    => 1,
           server_serie        => '15.0',
           server_version      => '15.0-20220912',
           server_version_info => [
                                    15,
                                    ( 0 ) x 2,
                                    'final',
                                    0,
                                    ''
                                  ]
         };
```
To authenticate we need to pass parameters in this exact order, last hash is to add envs
```perl
$ my $db="crm";
crm
$ my $username = 'alex@openfoodfacts.org'
$ my $pwd = "************";
$ my $uid = $xmlrpc->call('authenticate', ($db, $username, $pwd, {}));
13
$ $xmlrpc = XML::RPC->new('https://connect-test.openfoodfacts.org//xmlrpc/2/object');
$ $xmlrpc->call('execute_kw', ($db, $uid, $pwd, 'res.partner', 'create', [{name => "New Partner"}]));
1260
```