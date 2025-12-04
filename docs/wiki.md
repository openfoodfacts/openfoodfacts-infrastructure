

## Key points

* Open Food Facts wiki is based on [MediaWiki](https://www.mediawiki.org/) wiki engine.
* It is hosted on a Debian 11 server with Apache2, PHP-FPM (Sury) and MariaDB.
* It is installed on a LXC container managed by Proxmox VE: CT 141 on ovh1 server.
* In 2025-12, we upgrated MediaWiki 1.35.2 to 1.43.


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
* Matomo: https://www.mediawiki.org/wiki/Extension:Matomo
  * There is 5.0 version but 4.0 is working fine without issues.
* ExternalData: https://www.mediawiki.org/wiki/Extension:ExternalData

These extensions are currently tested:

* Mermaid: https://www.mediawiki.org/wiki/Extension:Mermaid
* FlexDiagrams: https://www.mediawiki.org/wiki/Extension:FlexDiagrams

Other extensions that could be useful in the future:

* SlackNotifications: https://www.mediawiki.org/wiki/Extension:SlackNotifications ; we were using it in the past but "This extension is incompatible with MediaWiki 1.39 or any later release!"



## Staging

We put a basic authentication on the staging wiki to avoid being indexed by search engines and accessed by unauthorized users. It can leads to issues with VisualEditor and REST API if not properly configured.



## 2025-12 upgrade notes

* MediaWiki 1.35.2 is used in production.
* [MediaWiki 1.43](https://www.mediawiki.org/wiki/MediaWiki_1.43) is the latest LTS version ([supported until December 2027](https://www.mediawiki.org/wiki/Version_lifecycle#Versions_and_their_end-of-life)).
  * We choose not to upgrade to 1.44 because it is not LTS, and only maintained through June 2026.
* PHP 8.2.x and 8.3.x are also supported by MediaWiki 1.43. **PHP 8.4.x is not**.

```bash
# Install PHP from Sury repository to get multiple PHP versions
apt install extrepo
extrepo enable sury # we use https://deb.sury.org/ repository to get multiple PHP versions
apt update
apt install php7.4-{cli,common,curl,fpm,gd,imagick,imap,intl,json,mbstring,mysql,opcache,readline,xml,zip}
systemctl enable php7.4-fpm # Otherwise current website will lead to 500
update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/lib/php/7.4/sapi/fpm 74


# Install PHP 8.3 from Sury repository
apt install php8.3-{cli,common,curl,fpm,gd,imagick,imap,intl,json,mbstring,mysql,opcache,readline,xml,zip}
systemctl enable php8.3-fpm
systemctl start php8.3-fpm
update-alternatives --install /usr/sbin/php-fpm php-fpm /usr/lib/php/8.3/sapi/fpm 83
update-alternatives --set php-fpm /usr/lib/php/8.3/sapi/fpm
update-alternatives --set php /usr/bin/php8.3

php -v # verify

# Modify Apache configuration to use PHP 8.3 FPM
a2disconf php7.4-fpm
systemctl stop php7.4-fpm
systemctl disable php7.4-fpm # stop at next reboot

a2enconf php8.3-fpm
systemctl restart apache2

# Fix conf file
cp /etc/apache2/sites-available/off-wiki.rn7.net.conf /etc/apache2/sites-available/wiki.openfoodfacts.org.conf
ln -s /etc/apache2/sites-available/wiki.openfoodfacts.org.conf /etc/apache2/sites-enabled/wiki.openfoodfacts.org.conf
rm /etc/apache2/sites-enabled/off-wiki.rn7.net.conf
systemctl restart apache2

nano /etc/apache2/sites-available/wiki.openfoodfacts.org.conf
# Ensure the PHP-FPM socket path is correct for PHP 8.3:
#    SetHandler "proxy:unix:/run/php/php8.3-fpm.sock|fcgi://localhost/" 
systemctl restart apache2


# Modify ./LocalSettings.php if necessary to adjust any deprecated settings
# * $wgServer = "https://test-wiki.openfoodfacts.org";

# Open https://wiki.openfoodfacts.org/Special:Version to verify PHP version and installed extensions

# Backup existing wiki
mkdir -p /var/www/wiki.openfoodfacts.org2/
chown -R www-data:www-data /var/www/wiki.openfoodfacts.org2/
cp -r /var/www/wiki.openfoodfacts.org/* /var/www/wiki.openfoodfacts.org2/

# Install MediaWiki 1.43.5
cd /var/www/wiki.openfoodfacts.org/
wget https://releases.wikimedia.org/mediawiki/1.43/mediawiki-1.43.5.tar.gz
tar -xzf mediawiki-1.43.5.tar.gz --strip-components=1

# Run update script
apt install composer
runuser -u www-data -- composer update --no-dev
runuser -u www-data -- php maintenance/run.php update.php

# Fix cache directory permissions if needed
chown -R www-data:www-data /var/www/wiki.openfoodfacts.org
chmod -R 755 /var/www/wiki.openfoodfacts.org/cache

```



### Updating some extensions

```bash
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



### Visual Editor issue

If the interface only shows the wikitext editor instead of the Visual Editor, even after enabling the VisualEditor extension, it can be because you're browsing the wiki in "mobile mode". To fix this, switch to the desktop mode by clicking on the "Desktop site" link at the bottom of the page. VisualEditor is not supported in mobile mode.



### Code change for wiki look and feel

#### Vector-2022 skin usage
```php
// Vector-2022 should be used instead of Vector. In LocalSettings.php:
$wgDefaultSkin = "vector-2022";

// Enable Vector Night Mode
$wgVectorNightMode['beta'] = true;
$wgVectorNightMode['logged_out'] = true;
$wgVectorNightMode['logged_in'] = true;
$wgDefaultUserOptions['vector-theme'] = 'os';

```


#### Logo configuration

With the Vector-2022 skin, the logo configuration has changed. Instead of using the old `$wgLogo` variable, we now use the `$wgLogos` array to define multiple logo versions for different uses.

Vertical logo (icon) is not suited anymore, we have changed to an horizontal logo for better appearance in the header: https://wiki.openfoodfacts.org/File:CMJN_HORIZONTAL_WHITE_BG_OFF.svg

```php
// In LocalSettings.php
## Set the site logo(s) using the modern $wgLogos array
$wgLogos = [
    // 1. The 'icon' key is REQUIRED for the Vector-2022 skin (upper-left, 50x50px)
    'icon' => "$wgScriptPath/images/6/65/CMJN_HORIZONTAL_WHITE_BG_OFF.svg",
    
    // 2. '1x' and '2x' keys are for backwards compatibility with older skins (e.g., 135x135px)
    '1x' => "$wgScriptPath/images/f/ff/Logo-135x135b.png",
    //'2x' => "$wgScriptPath/images/openfoodfacts-logo-270x270.png",
    
    // Optional: Include a wordmark if you want text next to the icon in the header (Vector-2022)
    //'wordmark' => [ 
        //'src' => "$wgScriptPath/images/openfoodfacts-wordmark.svg", 
        // Define max width/height for the wordmark if necessary
        // 'width' => 124, 
        // 'height' => 32 
    //],
];

```

We also have modified the [CSS related to Vector](https://test-wiki.openfoodfacts.org/MediaWiki:Vector-2022.css) to hide the wordmark text and adapt the logo size:

```css
/* https://test-wiki.openfoodfacts.org/MediaWiki:Vector-2022.css */

/* Hide the site name/wordmark text in the header for Vector-2022 skin */
.mw-logo-wordmark {
    display: none !important;
}

/* Logo size */
.mw-logo-icon {
    width: 220px; 
    height: 80px;
}

.vector-header {
    padding-top: 0;
    padding-bottom:0;
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

```bash
nano /var/www/wiki.openfoodfacts.org/extensions/AuthProductOpener/AuthProductOpener.body.php
```

```php
/**
 * Fix deprecated Http class usage (if Class "Http" not found error occurs)
 * The Http class was removed in MediaWiki 1.34+
 *
 * Update custom extensions to use HttpRequestFactory
 * Example in AuthProductOpener or other custom extensions:
 * OLD: Http::post
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


### Enabling REST API routing

This is still an  issue to be addressed, as search-as-you-type is not working.



### Dark mode

There are several things to be addressed for better dark mode support.

The wiki's logo should have a specific version for dark mode (light version for dark background).



### Login

The old login system using Open Food Facts's cookies need to be changed.

See @hangy's proposal to use Keycloack: https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/543


