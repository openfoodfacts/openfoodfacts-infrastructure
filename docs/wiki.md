

## Key points

* Open Food Facts wiki is based on [MediaWiki](https://www.mediawiki.org/) wiki engine.
* It is hosted on a Debian 11 server with Apache2, PHP-FPM (Sury) and MariaDB.
* It is installed on a LXC container managed by Proxmox VE: CT 141 on ovh1 server.
* At 2025-11, it runs MediaWiki 1.35.2.


## Good practices

* We don't install too much extensions, to avoid security issues and performance problems.
* Every new extension should be discussed with the team before installation.
* We use a staging environment to test updates before applying them on production.


## Extensions

Used extensions are listed here: https://wiki.openfoodfacts.org/Special:Version

The following extensions are installed and/or used:

* Interwiki: installed with MediaWiki (and Merged into core MediaWiki 1.44): https://www.mediawiki.* Replace Text: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:Replace_Text
* WikiEditor: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:WikiEditor
* VisualEditor: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:VisualEditor
* Parser hooks:
  * Cite: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:Cite
org/wiki/Extension:Interwiki
  * CategoryTree: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:CategoryTree
  * InputBox: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:InputBox
  * ParserFunctions: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:ParserFunctions
  * TemplateData: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:TemplateData
* Others:
  * MultimediaViewer: installed with MediaWiki: https://www.mediawiki.org/wiki/Extension:MultimediaViewer


These extensions have been manually installed:

* AuthProductOpener: custom extension to allow Open Food Facts user authentication on other Open Food Facts projects (blog, apps...)
* MobileFrontend: https://www.mediawiki.org/wiki/Extension:MobileFrontend
* FontAwesome: https://www.mediawiki.org/wiki/Extension:FontAwesome
* UniversalLanguageSelector: https://www.mediawiki.org/wiki/Extension:UniversalLanguageSelector
* ExternalData: https://www.mediawiki.org/wiki/Extension:ExternalData
* Matomo: https://www.mediawiki.org/wiki/Extension:Matomo
  * There is 5.0 version but 4.0 is working fine without issues.

These extensions are currently tested:

* Mermaid: https://www.mediawiki.org/wiki/Extension:Mermaid
* FlexDiagrams: https://www.mediawiki.org/wiki/Extension:FlexDiagrams

Other extensions that could be useful in the future:

* SlackNotifications: https://www.mediawiki.org/wiki/Extension:SlackNotifications ; we were using it in the past but "This extension is incompatible with MediaWiki 1.39 or any later release!"

## Staging

We put a basic authentication on the staging wiki to avoid being indexed by search engines and accessed by unauthorized users. It can leads to issues with VisualEditor and REST API if not properly configured.

## 2025-11 upgrade notes

* MediaWiki 1.35.2 is used in production.
* [MediaWiki 1.43](https://www.mediawiki.org/wiki/MediaWiki_1.43) is the latest LTS version ([supported until December 2027](https://www.mediawiki.org/wiki/Version_lifecycle#Versions_and_their_end-of-life)).
  * We choose not to upgrade to 1.44 because it is not LTS, and only maintained through June 2026.
* PHP 8.2.x and 8.3.x are also supported by MediaWiki 1.43. PHP 8.4.x is not.

```bash
# Install PHP 8.3 from Sury repository
apt install php8.3-{cli,common,curl,fpm,gd,imagick,imap,intl,mbstring,mysql,opcache,readline,xml,zip}
systemctl disable php7.4-fpm
systemctl enable php8.3-fpm
systemctl start php8.3-fpm
update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/lib/php/8.3/sapi/fpm 83
update-alternatives --set php-fpm /usr/lib/php/8.3/sapi/fpm
update-alternatives --set php /usr/bin/php8.3

php -v # verify

# Modify Apache configuration to use PHP 8.3 FPM
a2disconf php7.4-fpm
a2disconf php8.4-fpm
a2enconf php8.3-fpm
systemctl restart apache2

# Fix conf file
mv /etc/apache2/sites-available/off-wiki.rn7.net.conf /etc/apache2/sites-available/wiki.openfoodfacts.org.conf
ln -s /etc/apache2/sites-available/wiki.openfoodfacts.org.conf /etc/apache2/sites-enabled/wiki.openfoodfacts.org.conf
rm /etc/apache2/sites-enabled/off-wiki.rn7.net.conf


# Modify ./LocalSettings.php if necessary to adjust any deprecated settings
# * $wgServer = "https://test-wiki.openfoodfacts.org";

# Open https://wiki.openfoodfacts.org/Special:Version to verify PHP version and installed extensions

# Backup existing wiki
mkdir -p /var/www/wiki.openfoodfacts.org2/
chown www-data:www-data /var/www/wiki.openfoodfacts.org2/
cp -r /var/www/wiki.openfoodfacts.org/* /var/www/wiki.openfoodfacts.org2/

# Install MediaWiki 1.43.5
cd /var/www/wiki.openfoodfacts.org/
wget https://releases.wikimedia.org/mediawiki/1.43/mediawiki-1.43.5.tar.gz
tar -xzf mediawiki-1.43.5.tar.gz --strip-components=1

# Run update script
php maintenance/update.php

apt install composer
runuser -u www-data -- composer update --no-dev
runuser -u www-data -- php maintenance/run.php update.php

# Fix cache directory permissions if needed
chown -R www-data:www-data /var/www/wiki.openfoodfacts.org
chmod -R 755 /var/www/wiki.openfoodfacts.org/cache

# Enable REST API routing (if rest.php returns 404)
# The requests go through nginx reverse proxy with HTTP Basic Auth
# Browser JavaScript cannot send Basic Auth credentials automatically

# Fix: Allow REST API endpoints without authentication in nginx config
# Edit the nginx configuration on ovh1-reverse-proxy server
# Location: /etc/nginx/sites-available/wiki.openfoodfacts.org

# Add this location block before the main location block that requires auth:
# location ~ ^/rest\.php {
#     # No auth_basic here - allow public access to REST API
#     proxy_pass http://backend_wiki;
#     proxy_set_header Host $host;
#     proxy_set_header X-Real-IP $remote_addr;
#     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#     proxy_set_header X-Forwarded-Proto $scheme;
# }

# Similarly for api.php if needed:
# location ~ ^/api\.php {
#     proxy_pass http://backend_wiki;
#     # ... same headers
# }

# After editing nginx config:
# nginx -t
# systemctl reload nginx

# Test REST API without authentication:
curl "https://test-wiki.openfoodfacts.org/rest.php/v1/search/title?q=Recent&limit=10"

# The search-as-you-type should now work in the browser

# Update some extensions
wget https://extdist.wmflabs.org/dist/extensions/MobileFrontend-REL1_43-148ff5d.tar.gz
rm -rf ./extensions/MobileFrontend
tar -xzf MobileFrontend-REL1_43-148ff5d.tar.gz -C extensions/
rm ./MobileFrontend-REL1_43-148ff5d.tar.gz

wget https://extdist.wmflabs.org/dist/extensions/UniversalLanguageSelector-REL1_43-88a9491.tar.gz
rm -rf ./extensions/UniversalLanguageSelector
tar -xzf UniversalLanguageSelector-REL1_43-88a9491.tar.gz -C extensions/
rm ./UniversalLanguageSelector-REL1_43-88a9491.tar.gz
```

### Code change for wiki look and feel

```php
// Vector-2022 should be used instead of Vector. In LocalSettings.php:
$wgDefaultSkin = "vector-2022";

// Enable Vector Night Mode
$wgVectorNightMode['beta'] = true;
$wgVectorNightMode['logged_out'] = true;
$wgVectorNightMode['logged_in'] = true;
$wgDefaultUserOptions['vector-theme'] = 'os';


## Set the site logo(s) using the modern $wgLogos array
$wgLogos = [
    // 1. The 'icon' key is REQUIRED for the Vector-2022 skin (upper-left, 50x50px)
    'icon' => "$wgScriptPath/images/f/ff/Logo-135x135b.png",
    
    // 2. '1x' and '2x' keys are for backwards compatibility with older skins (e.g., 135x135px)
    '1x' => "$wgScriptPath/images/f/ff/Logo-135x135b.png",
    '2x' => "$wgScriptPath/images/openfoodfacts-logo-270x270.png",
    
    // Optional: Include a wordmark if you want text next to the icon in the header (Vector-2022)
    'wordmark' => [ 
        'src' => "$wgScriptPath/images/openfoodfacts-wordmark.svg", 
        // Define max width/height for the wordmark if necessary
        // 'width' => 124, 
        // 'height' => 32 
    ],
];


```

Modify Vector-2022 CSS if needed:

```css
/* Open https://test-wiki.openfoodfacts.org/MediaWiki:Vector-2022.css */

/* Hide the site name/wordmark text in the header for Vector-2022 skin */
.mw-logo-wordmark {
    display: none !important;
}

```

### Font awesome extension usage

```php
// In LocalSettings.php
// Enable FontAwesome extension
wfLoadExtension( 'FontAwesome' );
```

Verify it's working:
* https://wiki.openfoodfacts.org/Special:Version
* https://wiki.openfoodfacts.org/Wiki_Icons


### Code changes for custom extensions

```php
/**
 * Fix deprecated Http class usage (if Class "Http" not found error occurs)
 * The Http class was removed in MediaWiki 1.34+
 *
 * Update custom extensions to use HttpRequestFactory
 * Example in AuthProductOpener or other custom extensions:
 * OLD: Http::get($url)
 * NEW:
 */
use MediaWiki\MediaWikiServices;
$httpRequestFactory = MediaWikiServices::getInstance()->getHttpRequestFactory();
$httpRequestFactory->get($url)

/**
 * Fix deprecated Hooks class usage (if Class "Hooks" not found error occurs)
 * The Hooks class was removed in MediaWiki 1.35+
 * Update custom extensions:
 * OLD: Hooks::register('ParserFirstCallInit', ...)
 * NEW:
 */
use MediaWiki\Hook\ParserFirstCallInitHook;
// or use the HookContainer service:
use MediaWiki\HookContainer\HookContainer;
$hookContainer = MediaWikiServices::getInstance()->getHookContainer();
$hookContainer->register('HookName', $callback);

/**
 * Fix deprecated User class methods (if deprecated method warnings occur)
 *
 * Several User class methods were removed in MediaWiki 1.35+
 * Update custom extensions:
 * OLD: $user->isLoggedIn()
 * NEW: $user->isRegistered()
 * 
 * OLD: $user->isAnon()
 * NEW: !$user->isRegistered()
 *
 * OLD: $user->getId()
 * NEW: $user->getId() still works, but consider using UserIdentity interface
 * 
 * Fix deprecated $wgUser global variable (if "$wgUser was deprecated" warning occurs)
 * The $wgUser global was deprecated in MediaWiki 1.35+
 * Update custom extensions:
 * OLD: global $wgUser;
 * NEW: Use RequestContext or inject user via hooks
 */
use MediaWiki\MediaWikiServices;
$user = RequestContext::getMain()->getUser();
# Or in hooks that provide a User parameter, use that parameter directly
# instead of accessing $wgUser


//wfLoadExtension( 'MobileFrontend');
//wfLoadExtension( 'UniversalLanguageSelector' );

```
