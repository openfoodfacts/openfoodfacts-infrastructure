
diff -r -u --exclude logs/ --exclude html/images/products/ --exclude html/data '--exclude=html/illustrations' --exclude html/files --exclude html/exports --exclude 'scripts/*.csv' --exclude deleted.images --exclude tmp/ --exclude new_images/ '--exclude=build-cache' '--exclude=debug' '--exclude=node_modules' '--exclude=node_modules.old' '--exclude=users' '--exclude=lists' '--exclude=data' '--exclude=orgs' /home/off/openfoodfacts-server/.gitignore /srv/off/.gitignore
--- /home/off/openfoodfacts-server/.gitignore	2023-02-28 14:40:05.359077955 +0100

# TODO copy

```
Only in /srv/off/lib/ProductOpener: Config2.pm # done
Only in /srv/off: log.conf # done
Only in /srv/off: minion_log.conf # done

```

# TODO link

```
Only in /srv/off/po: site-specific # done
Only in /srv/off: products # done
```


# Move to data or html_data and link ?
```
Only in /srv/off/: files # done
Only in /srv/off: new_images  # done

Only in /srv/off/html: dump  # done bson est dans dump et pas dans data

Only in /srv/off/html: exports # done

Only in /srv/off: imports # done
Only in /srv/off: deleted_products # done
Only in /srv/off: deleted_products_images #done

Only in /srv/off: export_files # done
```

# Put in git

IMPORTANT: verify there are no private urls or keys ! (if yes put in Config2.pm)
```
Only in /srv/off/html/.well-known: apple-app-site-association # done
Only in /srv/off/html/.well-known: apple-developer-merchantid-domain-association # done

Only in /srv/off/scripts: import_carrefour.sh

In obsolete:
Only in /srv/off/scripts: import_ldc.sh
Only in /srv/off/scripts: import_ocr_nutriscore.sh
Only in /srv/off/scripts: import_stores_be_delhaize.sh

```

# ASK Stephane
```
Only in /srv/off: bad-users  # remove
Only in /srv/off: missions  # sauvegarder ?
Only in /srv/off: reverted_products # à mettre dans data…
Only in /srv/off: translate # à mettre dans data…
Only in /srv/off: spam_users # remove


Only in /srv/off: Lang.openfoodfacts.org.sto  # it's now in data/
Only in /srv/off: Lang_select_country_options.sto  # old stuff


What to keep from logs ? (can keep all on ovh3)  # faire un volume logs --> vieux logs dans un dossier

Only in /srv/off/packager-codes: FR-merge.csv  # remove
Only in /srv/off/packager-codes: IT-merge.csv  # remove


Only in /srv/off/conf/nginx/sites-available: labelme
Only in /srv/off/conf/nginx/sites-available: off-fr  # à sauvegarder -- done
Only in /srv/off/conf/nginx/sites-available: off-preprod  # remove
Only in /srv/off/conf/nginx/sites-available: whatsinmyshampoo  # historique - sauvegarder - useless: content no more there
Only in /srv/off/conf/nginx/sites-available: whatsinmyyogurt  # historique - sauvegarder - useless: content no more there

Only in /srv/off/html: 706f6c558c3ea05ed0cb6ec4f5cce053.html # remove
Only in /srv/off/html: BingSiteAuth.xml?url=http:%2F%2Fopenfoodfacts.org%2F # remove
Only in /srv/off/html: OpenFoodFacts-CCC201209.pdf # move to drive Computer Cooking Contest 2012 - Lyon – Sept. 3rd 2012 - done https://drive.google.com/file/d/1AxYDIgqvjgOfpZ8ImFzyIl5vqI_L8Isn/view?usp=sharing
Only in /srv/off/html: android  # remove
Only in /srv/off/html: apps/off.apk  # move in drive - done - https://drive.google.com/file/d/1TgMoDTRtgA7LdkNSrOJGGyMp7wu3D0Em/view?usp=drive_link
Only in /srv/off/html: ??.index.html  # lié aux version statiques --> to remove
Only in /srv/off/html/js: hunger-game  # remove
Only in /srv/off/html/js: lang  # remove
Only in /srv/off/html: langs.html  # remove
Only in /srv/off/html: last_delta_export.txt  # remove

# move to a zfs and serve with nginx
Only in /srv/off/html: madenearme-uk.html
Only in /srv/off/html: madenearme.html
Only in /srv/off/html: madenearme.html.world
Only in /srv/off/html: madenearyou-uk.html
Only in /srv/off/html: cestemballepresdechezvous-embed.html
Only in /srv/off/html: cestemballepresdechezvous.html

Only in /srv/off/html: robots-disallow.txt # remove (included in robots.txt)

# remove - but schedule feeds more smartly
Only in /srv/off/scripts: gen_all_feeds.sh
Only in /srv/off/scripts: gen_all_feeds_daily.sh
Only in /srv/off/scripts: gen_all_feeds_off.sh

Only in /srv/off/scripts: minion.pl # remove
Only in /srv/off/scripts: minion_import.pl # remove

# to remove
Only in /srv/off/scripts: scanbot.2018.products.csv
Only in /srv/off/scripts: scanbot.20180908-20190918.csv
Only in /srv/off/scripts: scanbot.2019
Only in /srv/off/scripts: scanbot.2019.products.csv
Only in /srv/off/scripts: scanbot.2020
Only in /srv/off/scripts: scanbot.2020.log
Only in /srv/off/scripts: scanbot.2020.products.csv
Only in /srv/off/scripts: scanbot.2020_fr
Only in /srv/off/scripts: scanbot.log
Only in /srv/off/scripts: scanbot.old
Only in /srv/off/scripts: scanbot.products.2019.csv
Only in /srv/off/scripts: scanbot.products.2019.found.10k.csv
Only in /srv/off/scripts: scanbot.products.2019.found.csv
Only in /srv/off/scripts: scanbot.products.2019.not_found.10k.csv
Only in /srv/off/scripts: scanbot.products.2019.not_found.csv
Only in /srv/off/scripts: scanbot.products.2019.producers.csv
Only in /srv/off/scripts: scanbot.products.2020.csv
Only in /srv/off/scripts: scanbot.products.2020.found.csv
Only in /srv/off/scripts: scanbot.products.2020.not_found.csv
Only in /srv/off/scripts: scanbot.products.2020.producers.csv
Only in /srv/off/scripts: scanbot.products.csv
Only in /srv/off/scripts: scanbot.sh
Only in /srv/off/scripts: scanbot_count_nutriscore.pl
Only in /srv/off/scripts: scanbot_fr.log
Only in /srv/off/scripts: scanbot_fr.pl
Only in /srv/off/scripts: scanbot_fr.products.2020.found.csv
Only in /srv/off/scripts: scanbot_fr.products.csv
Only in /srv/off/scripts: scanbot_stats.pl
Only in /srv/off/scripts: scans.20190422-20190510.csv
Only in /srv/off/scripts: scans.20190422-20190510.fr.csv
Only in /srv/off/scripts: scans.20190422-20190510.fr.quality.csv
Only in /srv/off/scripts: scans.20190422-20190510.fr.random-100.csv
Only in /srv/off/scripts: scans.20190422-20190510.fr.random-100.quality.csv
Only in /srv/off/scripts: scans.20190422-20190510.fr.random-1000.csv
Only in /srv/off/scripts: scans.20190422-20190510.fr.random-1000.quality.csv


Only in /srv/off/scripts: select_random_sample.pl  # remove

Only in /srv/off/scripts: update_all_products_ogm.pl  # remove
Only in /srv/off/scripts: update_one_product.pl  # remove
Only in /srv/off/scripts: update_some_products.pl  # remove
Only in /srv/off/scripts: update_texts_from_wiki.pl  # remove
Only in /srv/off/scripts: update_users.pl  # remove
Only in /srv/off/scripts: upload_photos.pl  # already in scripts/obsolete

# keep last emails exports to brevo - done but put in srv/off/data
Only in /srv/off/scripts: emails10_diff.txt
Only in /srv/off/scripts: emails10_diff_plus_random.txt
Only in /srv/off/scripts: emails10_old_format_sorted.txt
Only in /srv/off/scripts: emails10_sorted.txt


Only in /srv/off/html/.well-known: pki-validation # old globalsign validation - remove
```




# ASK Pierre
```
Only in /srv/off: crowdin-gic.yml  # remove
```



# TO remove
```
Only in /srv/off: tmp

Only in /srv/off/lib/ProductOpener: SiteLang.pm # obsolete
Only in /srv/off/lib/ProductOpener: SiteQuality.pm # obsolete
Only in /srv/off/lib/ProductOpener: SiteLang_obf.pm # obsolete
Only in /srv/off/lib/ProductOpener: SiteLang_off.pm # obsolete
Only in /srv/off/lib/ProductOpener: SiteQuality_off.pm # obsolete

Only in /srv/off: orgs_glns.sto # not needed any more
Only in /srv/off: users_emails.sto # not needed any more

Only in /srv/off/scripts: import_carrefour_off1.sh # it's import_carrefour_pro_off1.sh now
Only in /srv/off/scripts: import_fleurymichon_old.pl # obsolete
Only in /srv/off/scripts: import_barilla.sh # already in obsolete/
Only in /srv/off/scripts: import_baskalia_pechalou.sh # already in obsolete/
Only in /srv/off/scripts: import_casino.sh # already in obsolete/
Only in /srv/off/scripts: import_foodrepo.sh # already in obsolete/
Only in /srv/off/scripts: import_harrys.sh # already in obsolete/
Only in /srv/off/scripts: import_iglo.sh # already in obsolete/
Only in /srv/off/scripts: import_mxbot.sh # already in obsolete/
Only in /srv/off/scripts: import_openfood_ch.pl # already in obsolete/
Only in /srv/off/scripts: import_openfood_ch_name_translations.pl # already in obsolete/
Only in /srv/off/scripts: import_saintelucie.sh # already in obsolete/
Only in /srv/off/scripts: import_sodebo.pl # already in obsolete/
Only in /srv/off/scripts: import_us_ndb.pl # already in obsolete/

Only in /srv/off/cgi: README-IMAGE-DATA-SET.TXT
Only in /srv/off/cgi: madenearme.pl
Only in /srv/off/cgi: madenearyou.pl
Only in /srv/off/cgi: user-old.pl
Only in /srv/off/cgi: disabled
Only in /srv/off/cgi: i18n
Only in /srv/off/cgi: m.html
Only in /srv/off/cgi: product_jqm_multilingual.pl.ok
Only in /srv/off/cgi: profile.pl
Only in /srv/off/cgi: ratemyrecipe_redirect_test.pl
Only in /srv/off/cgi: reset_password_for_user.pl
Only in /srv/off/cgi: search2.pl
Only in /srv/off/cgi: sto2json.pl
Only in /srv/off/cgi: user2.pl
Only in /srv/off/conf/nginx/snippets: ssl.preprod.openfoodfacts.org
Only in /srv/off/docs: explanations
Only in /srv/off/docs: how-to-guides
Only in /srv/off/docs: introduction
Only in /srv/off/docs: reference
Only in /srv/off/docs: tutorials
Only in /srv/off: ecoscore
Only in /srv/off: forest-footprint
Only in /srv/off: gulpfile.js
Only in /srv/off/html/.well-known: acme-challenge
Only in /srv/off/html: Store.debug.txt
Only in /srv/off/html: bak
Only in /srv/off/html: be-fr.index.html
Only in /srv/off/html: be.index.html
Only in /srv/off/html: bower_components
Only in /srv/off/html: br.index.html
Only in /srv/off/html: ca-fr.index.html
Only in /srv/off/html: ca.index.html
Only in /srv/off/html: cestfabriquepresdechezvous.html
Only in /srv/off/html: ch-fr.index.html
Only in /srv/off/html: cl.index.html
Only in /srv/off/html: co.index.html
Only in /srv/off/html: cop26
Only in /srv/off/html: countries.html
Only in /srv/off/html: de.index.html
Only in /srv/off/html: es.index.html
Only in /srv/off/html: foundation
Only in /srv/off/html: fr.contribuer.html
Only in /srv/off/html: fr.decouvrir.html
Only in /srv/off/html: fr.index.html
Only in /srv/off/html: gzip
Only in /srv/off/html/js: gnuwilliam-jQuery-Tags-Input-a648557
Only in /srv/off/html/js: highcharts.4.0.4.js
Only in /srv/off/html/js: highcharts.js
Only in /srv/off/html/js: highcharts.js.2.2.5
Only in /srv/off/html/js: highcharts.js.3.0.1
Only in /srv/off/html/js: highcharts.js.4.0.4
Only in /srv/off/html/js: jQueryRotateCompressed.2.1.js
Only in /srv/off/html/js: jquery
Only in /srv/off/html/js: jquery-interestingviews-selectclip.js
Only in /srv/off/html/js: jquery-jvectormap-1.2.2.css
Only in /srv/off/html/js: jquery-jvectormap-1.2.2.min.js
Only in /srv/off/html/js: jquery-jvectormap-world-mill-en.js
Only in /srv/off/html/js: jquery-ui-1.11.4
Only in /srv/off/html/js: jquery.autocomplete.20150416
Only in /srv/off/html/js: jquery.autoresize.js
Only in /srv/off/html/js: jquery.cookie.js
Only in /srv/off/html/js: jquery.cookie.js.gz
Only in /srv/off/html/js: jquery.cookie.js.js
Only in /srv/off/html/js: jquery.cookie.min.js
Only in /srv/off/html/js: jquery.dataTables.min.js
Only in /srv/off/html/js: jquery.fileupload-ip.js
Only in /srv/off/html/js: jquery.fileupload-ip.min.js
Only in /srv/off/html/js: jquery.fileupload.js
Only in /srv/off/html/js: jquery.fileupload.min.js
Only in /srv/off/html/js: jquery.form.js
Only in /srv/off/html/js: jquery.form.js.old
Only in /srv/off/html/js: jquery.iframe-transport.js
Only in /srv/off/html/js: jquery.iframe-transport.min.js
Only in /srv/off/html/js: jquery.imgareaselect-0.9.8
Only in /srv/off/html/js: jquery.imgareaselect-0.9.8.zip
Only in /srv/off/html/js: jquery.rotate.js
Only in /srv/off/html/js: jquery.tagsinput.20150416
Only in /srv/off/html/js: jquery.tagsinput.20160520
Only in /srv/off/html/js: jquery.tagsinput.css
Only in /srv/off/html/js: jquery.tagsinput.js
Only in /srv/off/html/js: jquery.transit.min.js
Only in /srv/off/html/js: jqueryui
Only in /srv/off/html/js: leaflet
Only in /srv/off/html/js: leaflet-0.7
Only in /srv/off/html/js: load-image.min.js
Only in /srv/off/html/js: mColorPicker.js
Only in /srv/off/html/js: mColorPicker_min.js
Only in /srv/off/html/js: mColorPicker_min.js.old
Only in /srv/off/html/js: master
Only in /srv/off/html/js: off-vocal.apk
Only in /srv/off/html/js: off.apk
Only in /srv/off/html/js: product-foundation.js
Only in /srv/off/html/js: product.js
Only in /srv/off/html/js: select2
Only in /srv/off/html/js: select2-3.4.5
Only in /srv/off/html/js: xoxco-jQuery-Tags-Input-6d2b1d3
Only in /srv/off/html/js: xx.html
Only in /srv/off/html/js: xx.txt
Only in /srv/off/html/js: zeroclipboard
Only in /srv/off/html/js: zeroclipboard-1.0.7.tar
Only in /srv/off/html: make_static.sh
Only in /srv/off/html: md5sum
Only in /srv/off/html: mx.index.html
Only in /srv/off/html: nl.index.html
Only in /srv/off/html: products.js
Only in /srv/off/html: products.old.shtml
Only in /srv/off/html: products.png
Only in /srv/off/html: products_countries.html
Only in /srv/off/html: products_countries.js
Only in /srv/off/html: products_langs.html
Only in /srv/off/html: pt.index.html
Only in /srv/off/html: resources
Only in /srv/off/html: rss
Only in /srv/off/html: search.html
Only in /srv/off/html: search.json
Only in /srv/off/html: sha256sum
Only in /srv/off/html: static
Only in /srv/off/html: uk.index.html
Only in /srv/off/html: us.index.html
Only in /srv/off/html: world.index.html
Only in /srv/off/icons: monkey_happy.96x96.png
Only in /srv/off/icons: nutrition.svg
Only in /srv/off/ingredients: .additives.txt.swp
Only in /srv/off/ingredients/additifs: authorized_additives.txt
Only in /srv/off/ingredients/additifs: extract_additives.pl
Only in /srv/off/ingredients: additives.txt.2
Only in /srv/off/ingredients: additives.txt.20141122
Only in /srv/off/ingredients: bak
Only in /srv/off/lib/ProductOpener: .Display.pm.swo
Only in /srv/off/lib/ProductOpener: Config.pm
Only in /srv/off/lib/ProductOpener: WL24 Lapin aux deux moutardes 400g 051218.docx
Only in /srv/off/lib/ProductOpener: cgi
Only in /srv/off/lib/ProductOpener: fix_countries_removed_by_yuka.pl
Only in /srv/off/lib/ProductOpener: import_openfood_ch.pl
Only in /srv/off/lib/ProductOpener: import_systemeu.pl
Only in /srv/off/lib/ProductOpener: Export.pm.2
Only in /srv/off/lib/ProductOpener: Users.pm.old
Only in /srv/off/lib/ProductOpener: lib
Only in /srv/off/lib/ProductOpener: po
Only in /srv/off/lib/ProductOpener: scripts
Only in /srv/off/lib/ProductOpener: t
Only in /srv/off/lib/ProductOpener: taxonomies
Only in /srv/off/lib: startup.pl
Only in /srv/off/madenearme: bak
Only in /srv/off: minion_log.conf
Only in /srv/off/po/common: common-web.pot
Only in /srv/off/po/common: obsolete.pot
Only in /srv/off/po/common: zh_backup.po
Only in /srv/off/scripts: -C
Only in /srv/off/scripts: .import_systemeu.pl.swp
Only in /srv/off/scripts: .json
Only in /srv/off/scripts: .remove_empty_products.pl.swp
Only in /srv/off/scripts: .update_packager_codes.pl.swn
Only in /srv/off/scripts: .update_packager_codes.pl.swo
Only in /srv/off/scripts: .update_packager_codes.pl.swp
Only in /srv/off/scripts: 10
Only in /srv/off/scripts: 11
Only in /srv/off/scripts: 13b
Only in /srv/off/scripts: 14
Only in /srv/off/scripts: 14b
Only in /srv/off/scripts: 15
Only in /srv/off/scripts: 43
Only in /srv/off/scripts: Blogs
Only in /srv/off/scripts: Icons.ttf
Only in /srv/off/scripts: MultimediaFileViewer?key=50758935_8997D87BA43FDE8FA03988E9D6D120B8&idFile=1551847&file=10203%2F03168930010128_Z7N1_s23.jpeg
Only in /srv/off/scripts: ProductOpener
Only in /srv/off/scripts: Tags.pm
Only in /srv/off/scripts: a
Only in /srv/off/scripts: add_random_column_to_csv.pl
Only in /srv/off/scripts: add_users_emails.pl
Only in /srv/off/scripts: aggregate_tags_and_generate_taxonomy.pl
Only in /srv/off/scripts: b
Only in /srv/off/scripts: b1
Only in /srv/off/scripts: b2
Only in /srv/off/scripts: bak
Only in /srv/off/scripts: bernard1.xlsx
Only in /srv/off/scripts: bernard2.xlsx
Only in /srv/off/scripts: best_remap
Only in /srv/off/scripts: best_remap_202105_at.filtered.csv
Only in /srv/off/scripts: best_remap_202105_at.filtered2.csv
Only in /srv/off/scripts: best_remap_202105_at.unfiltered.csv
Only in /srv/off/scripts: best_remap_202105_be.filtered.csv
Only in /srv/off/scripts: best_remap_202105_be.filtered2.csv
Only in /srv/off/scripts: best_remap_202105_be.unfiltered.csv
Only in /srv/off/scripts: best_remap_202105_fr.filtered.csv
Only in /srv/off/scripts: best_remap_202105_fr.filtered2.csv
Only in /srv/off/scripts: best_remap_202105_fr.unfiltered.csv
Only in /srv/off/scripts: best_remap_202105_ie.filtered.csv
Only in /srv/off/scripts: best_remap_202105_ie.filtered2.csv
Only in /srv/off/scripts: best_remap_202105_ie.unfiltered.csv
Only in /srv/off/scripts: best_remap_202105_nl.filtered.csv
Only in /srv/off/scripts: best_remap_202105_nl.filtered2.csv
Only in /srv/off/scripts: best_remap_202105_nl.unfiltered.csv
Only in /srv/off/scripts: bio-zentrale.1
Only in /srv/off/scripts: brands.txt
Only in /srv/off/scripts: brands.unique.txt
Only in /srv/off/scripts: change_userid.pl
Only in /srv/off/scripts: check_for_nans.pl
Only in /srv/off/scripts: convert_auchan_data.pl
Only in /srv/off/scripts: convert_barilla_data.pl
Only in /srv/off/scripts: convert_carrefour_data.sh
Only in /srv/off/scripts: convert_casino_data.pl
Only in /srv/off/scripts: convert_ferrero_data.pl
Only in /srv/off/scripts: convert_foodrepo_data.pl
Only in /srv/off/scripts: convert_iglo_data.pl
Only in /srv/off/scripts: convert_intermarche_data.pl
Only in /srv/off/scripts: convert_ldc_data.pl
Only in /srv/off/scripts: convert_saintelucie_data.pl
Only in /srv/off/scripts: convert_scamark_data.pl
Only in /srv/off/scripts: convert_yuka_fr_data.pl
Only in /srv/off/scripts: count_export_best_remap.sh
Only in /srv/off/scripts: credit_product_to_creator.pl
Only in /srv/off/scripts: d
Only in /srv/off/scripts: db
Only in /srv/off/scripts: delta
Only in /srv/off/scripts: edit_changes_ref.pl
Only in /srv/off/scripts: emails1.txt
Only in /srv/off/scripts: emails1.txt.sorted
Only in /srv/off/scripts: emails10_diff.txt
Only in /srv/off/scripts: emails10_diff_plus_random.txt
Only in /srv/off/scripts: emails10_old_format_sorted.txt
Only in /srv/off/scripts: emails10_sorted.txt
Only in /srv/off/scripts: emails2.diff.txt
Only in /srv/off/scripts: emails2.txt
Only in /srv/off/scripts: emails2.txt.sorted
Only in /srv/off/scripts: emails2_sorted.txt
Only in /srv/off/scripts: emails3.diff.txt
Only in /srv/off/scripts: emails3_sorted.txt
Only in /srv/off/scripts: emails4.txt
Only in /srv/off/scripts: emails4_diff.txt
Only in /srv/off/scripts: emails4_sorted.txt
Only in /srv/off/scripts: emails5_diff.txt
Only in /srv/off/scripts: emails5_sorted.txt
Only in /srv/off/scripts: emails6_diff.txt
Only in /srv/off/scripts: emails6_sorted.txt
Only in /srv/off/scripts: emails7_diff.txt
Only in /srv/off/scripts: emails7_sorted.txt
Only in /srv/off/scripts: emails8_diff.txt
Only in /srv/off/scripts: emails8_diff_plus_random.txt
Only in /srv/off/scripts: emails8_sorted.txt
Only in /srv/off/scripts: emails9_diff.txt
Only in /srv/off/scripts: emails9_diff_plus_random.txt
Only in /srv/off/scripts: emails9_sorted.txt
Only in /srv/off/scripts/equadis-import: README.md
Only in /srv/off/scripts/equadis-import: dereference.sh
Only in /srv/off/scripts/equadis-import: equadis-data
Only in /srv/off/scripts/equadis-import: equadis-xml2csv.js
Only in /srv/off/scripts/equadis-import: equadis-xml2json.js
Only in /srv/off/scripts/equadis-import: equadis2off.sh
Only in /srv/off/scripts: export_database_test.pl
Only in /srv/off/scripts: export_nutrients_taxonomy.pl
Only in /srv/off/scripts: export_nutriscore.pl
Only in /srv/off/scripts: extract_country_and_code.pl
Only in /srv/off/scripts: extract_jsons.pl
Only in /srv/off/scripts: ferrero
Only in /srv/off/scripts: ferrero2
Only in /srv/off/scripts: fix_code_stored_as_number.pl
Only in /srv/off/scripts: fix_countries_removed_by_yuka.pl
Only in /srv/off/scripts: fix_deleted_products.pl
Only in /srv/off/scripts: fix_leading_zeros.pl
Only in /srv/off/scripts: fix_product.pl
Only in /srv/off/scripts: fix_product2.pl
Only in /srv/off/scripts: franprix.pl
Only in /srv/off/scripts: gen_users_emails_list.pl.bak
Only in /srv/off/scripts: i
Only in /srv/off/scripts: iglo-master-final-2020.xlsx
Only in /srv/off/scripts: import_carrefour_off1.sh
Only in /srv/off/scripts: import_carrefour_test.sh
Only in /srv/off/scripts: import_carrefour.sh
Only in /srv/off/scripts: import_fleurymichon_old.pl
Only in /srv/off/scripts: import_barilla.sh
Only in /srv/off/scripts: import_baskalia_pechalou.sh
Only in /srv/off/scripts: import_casino.sh
Only in /srv/off/scripts: import_foodrepo.sh
Only in /srv/off/scripts: import_harrys.sh
Only in /srv/off/scripts: import_iglo.sh
Only in /srv/off/scripts: import_ldc.sh
Only in /srv/off/scripts: import_mxbot.sh
Only in /srv/off/scripts: import_ocr_nutriscore.sh
Only in /srv/off/scripts: import_openfood_ch.pl
Only in /srv/off/scripts: import_openfood_ch_name_translations.pl
Only in /srv/off/scripts: import_saintelucie.sh
Only in /srv/off/scripts: import_sodebo.pl
Only in /srv/off/scripts: import_stores_be_delhaize.sh
Only in /srv/off/scripts: import_us_ndb.pl
Only in /srv/off/scripts: index.html?module=API&method=Live.getLastVisitsDetails&idSite=2&period=month&date=2022-08-01&format=JSON&token_auth=5e488aef77864fd10902389eadea107b&filter=1
Only in /srv/off/scripts: index.txt
Only in /srv/off/scripts: infobot_dk_irma.pl
Only in /srv/off/scripts: l
Only in /srv/off/scripts: last_delta_export.txt
Only in /srv/off/scripts: ldc_export2.csv
Only in /srv/off/scripts: lea.csv
Only in /srv/off/scripts: list_tags.pl
Only in /srv/off/scripts: m.html
Only in /srv/off/scripts: madenearme.pl
Only in /srv/off/scripts: madenearyou.pl
Only in /srv/off/scripts: md5sum
Only in /srv/off/scripts: minion_export_test.pl
Only in /srv/off/scripts: minion_import_test.pl
Only in /srv/off/scripts: minion_producers_test.pl
Only in /srv/off/scripts: moderators.tsv
Only in /srv/off/scripts: mongodb_dump_uk.sh
Only in /srv/off/scripts: nohup.out
Only in /srv/off/scripts: nova.csv
Only in /srv/off/scripts: nova_stats_by_categories.pl
Only in /srv/off/scripts: nutrinet_libelles.pl
Only in /srv/off/scripts: nutrinet_libelles2.pl
Only in /srv/off/scripts: off.exemple.csv
Only in /srv/off/scripts/packager-codes: concatenate-csv-sections.py
Only in /srv/off/scripts/packager-codes: fi-packagers-xls2cvs.pl
Only in /srv/off/scripts/packager-codes: geocode.sh
Only in /srv/off/scripts: packager_codes.txt
Only in /srv/off/scripts: packager_codes.xml
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.1
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.10
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.11
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.12
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.13
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.14
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.15
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.16
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.2
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.3
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.4
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.5
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.6
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.7
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.8
Only in /srv/off/scripts: pate-a-tartiner-noisette-du-lot-et-garonne-cacao-lucien-georgelin.9
Only in /srv/off/scripts: po2jqueryi18n.pl
Only in /srv/off/scripts: pro_users_emails.txt
Only in /srv/off/scripts: process_new_image_off.sh
Only in /srv/off/scripts: products_-1_1544081016.json.gz
Only in /srv/off/scripts: products_-1_1544156383.json.gz
Only in /srv/off/scripts: products_-1_1544167671.json.gz
Only in /srv/off/scripts: products_-1_1544242716.json.gz
Only in /srv/off/scripts: products_-1_1544254303.json.gz
Only in /srv/off/scripts: products_-1_1544328739.json.gz
Only in /srv/off/scripts: products_-1_1544339445.json.gz
Only in /srv/off/scripts: products_-1_1544415619.json.gz
Only in /srv/off/scripts: products_-1_1544427387.json.gz
Only in /srv/off/scripts: products_-1_1544502732.json.gz
Only in /srv/off/scripts: products_-1_1544515039.json.gz
Only in /srv/off/scripts: products_-1_1544588411.json.gz
Only in /srv/off/scripts: products_-1_1544600362.json.gz
Only in /srv/off/scripts: remove_deleted_products_from_db.pl
Only in /srv/off/scripts: run_agena3000_import.sh
Only in /srv/off/scripts: scripts
Only in /srv/off/scripts: sha256sum
Only in /srv/off/scripts: test.pl
Only in /srv/off/scripts: test.tar
Only in /srv/off/scripts: test_additifs.pl
Only in /srv/off/scripts: test_food.pl
Only in /srv/off/scripts: test_ingredient_parser.pl
Only in /srv/off/scripts: test_quality.pl
Only in /srv/off/scripts: u
Only in /srv/off/scripts: update
Only in /srv/off/scripts: upload_photos_2016_franprix.pl
Only in /srv/off/scripts: upload_photos_2018_liege.pl
Only in /srv/off/scripts: upload_photos_foodvisor.sh
Only in /srv/off/scripts: upload_photos_perpignan.sh
Only in /srv/off/scripts: upload_photos_saintelucie_maisonduthe.sh
Only in /srv/off/scripts: upload_photos_scanparty_rotterdam_.sh
Only in /srv/off/scripts: upload_photos_scanparty_rotterdam_1.sh
Only in /srv/off/scripts: upload_photos_scanparty_rotterdam_2.sh
Only in /srv/off/scripts: upload_photos_scanparty_rotterdam_3.sh
Only in /srv/off/scripts: upload_photos_scanparty_rotterdam_4.sh
Only in /srv/off/scripts: upload_photos_scanparty_rotterdam_5.sh
Only in /srv/off/scripts: upload_photos_scanparty_rotterdam_6.sh
Only in /srv/off/scripts: upload_photos_scanparty_rotterdam_ekoplaza.sh
Only in /srv/off/scripts: users_names.txt
Only in /srv/off/scripts: users_pro_20221129.csv
Only in /srv/off/scripts: x
Only in /srv/off/scripts: xx
Only in /srv/off/scripts: xxx
Only in /srv/off/scripts: younes_mx_categories.csv
Only in /srv/off/scripts: younes_mx_categories_test.csv
Only in /srv/off: spellcheck.yaml
Only in /srv/off: t
Only in /srv/off/taxonomies: 20131124
Only in /srv/off/taxonomies: 20131125
Only in /srv/off/taxonomies: Makefile
Only in /srv/off/taxonomies: Store.debug.txt
Only in /srv/off/taxonomies: additives.result.sto
Only in /srv/off/taxonomies: additives.result.txt
Only in /srv/off/taxonomies: additives_classes.result.sto
Only in /srv/off/taxonomies: additives_classes.result.txt
Only in /srv/off/taxonomies: allergens.result.sto
Only in /srv/off/taxonomies: allergens.result.txt
Only in /srv/off/taxonomies: allergensCheck.txt
Only in /srv/off/taxonomies: amino_acids.result.sto
Only in /srv/off/taxonomies: amino_acids.result.txt
Only in /srv/off/taxonomies: bak
Only in /srv/off/taxonomies: bak2
Only in /srv/off/taxonomies: brands.txt
Only in /srv/off/taxonomies: categories.result.sto
Only in /srv/off/taxonomies: categories.result.txt
Only in /srv/off/taxonomies: categories.wip.txt
Only in /srv/off/taxonomies: compliant.txt
Only in /srv/off/taxonomies: containers.txt
Only in /srv/off/taxonomies: countries.result.sto
Only in /srv/off/taxonomies: countries.result.txt
Only in /srv/off/taxonomies: data_quality.result.sto
Only in /srv/off/taxonomies: data_quality.result.txt
Only in /srv/off/taxonomies: data_quality_bugs.result.sto
Only in /srv/off/taxonomies: data_quality_errors.result.sto
Only in /srv/off/taxonomies: data_quality_errors_producers.result.sto
Only in /srv/off/taxonomies: data_quality_info.result.sto
Only in /srv/off/taxonomies: data_quality_warnings.result.sto
Only in /srv/off/taxonomies: data_quality_warnings_producers.result.sto
Only in /srv/off/taxonomies: eu_establishments_sections.txt
Only in /srv/off/taxonomies: fao_zones.txt
Only in /srv/off/taxonomies: food_groups.result.sto
Only in /srv/off/taxonomies: food_groups.result.txt
Only in /srv/off/taxonomies: i
Only in /srv/off/taxonomies: improvements.result.sto
Only in /srv/off/taxonomies: improvements.result.txt
Only in /srv/off/taxonomies: ingredients.all.txt
Only in /srv/off/taxonomies: ingredients.result.sto
Only in /srv/off/taxonomies: ingredients.result.txt
Only in /srv/off/taxonomies: ingredients_analysis.result.sto
Only in /srv/off/taxonomies: ingredients_analysis.result.txt
Only in /srv/off/taxonomies: ingredients_processing.result.sto
Only in /srv/off/taxonomies: ingredients_processing.result.txt
Only in /srv/off/taxonomies: labels.result.sto
Only in /srv/off/taxonomies: labels.result.txt
Only in /srv/off/taxonomies: labels_categories.txt
Only in /srv/off/taxonomies: languages.result.sto
Only in /srv/off/taxonomies: languages.result.txt
Only in /srv/off/taxonomies: materials.txt
Only in /srv/off/taxonomies: minerals.result.sto
Only in /srv/off/taxonomies: minerals.result.txt
Only in /srv/off/taxonomies: misc.result.sto
Only in /srv/off/taxonomies: misc.result.txt
Only in /srv/off/taxonomies: nova_groups.result.sto
Only in /srv/off/taxonomies: nova_groups.result.txt
Only in /srv/off/taxonomies: nucleotides.result.sto
Only in /srv/off/taxonomies: nucleotides.result.txt
Only in /srv/off/taxonomies: nutrient-levels.txt
Only in /srv/off/taxonomies: nutrient_levels.result.sto
Only in /srv/off/taxonomies: nutrient_levels.result.txt
Only in /srv/off/taxonomies: nutrients.result.sto
Only in /srv/off/taxonomies: nutrients.result.txt
Only in /srv/off/taxonomies: nutriments.txt
Only in /srv/off/taxonomies/off: wip
Only in /srv/off/taxonomies: opff
Only in /srv/off/taxonomies: origins.all.txt
Only in /srv/off/taxonomies: origins.result.sto
Only in /srv/off/taxonomies: origins.result.txt
Only in /srv/off/taxonomies: other_nutritional_substances.result.sto
Only in /srv/off/taxonomies: other_nutritional_substances.result.txt
Only in /srv/off/taxonomies: packaging.all.txt
Only in /srv/off/taxonomies: packaging.result.sto
Only in /srv/off/taxonomies: packaging.result.txt
Only in /srv/off/taxonomies: packaging_materials.result.sto
Only in /srv/off/taxonomies: packaging_materials.result.txt
Only in /srv/off/taxonomies: packaging_recycling.result.sto
Only in /srv/off/taxonomies: packaging_recycling.result.txt
Only in /srv/off/taxonomies: packaging_shapes.result.sto
Only in /srv/off/taxonomies: packaging_shapes.result.txt
Only in /srv/off/taxonomies: packagings.txt
Only in /srv/off/taxonomies: periods_after_opening.result.sto
Only in /srv/off/taxonomies: periods_after_opening.result.txt
Only in /srv/off/taxonomies: preservation.result.sto
Only in /srv/off/taxonomies: preservation.result.txt
Only in /srv/off/taxonomies: recycling_bins.txt
Only in /srv/off/taxonomies: recycling_instructions.txt
Only in /srv/off/taxonomies: states.result.sto
Only in /srv/off/taxonomies: states.result.txt
Only in /srv/off/taxonomies: states_en.txt
Only in /srv/off/taxonomies: stores.txt
Only in /srv/off/taxonomies: taxonomies
Only in /srv/off/taxonomies: test.result.sto
Only in /srv/off/taxonomies: test.result.txt
Only in /srv/off/taxonomies: test_taxonomies.pl
Only in /srv/off/taxonomies: traces.result.sto
Only in /srv/off/taxonomies: vitamins.result.sto
Only in /srv/off/taxonomies: vitamins.result.txt
Only in /srv/off/taxonomies: x
Only in /srv/off/templates/api/knowledge-panels: ecoscore
Only in /srv/off/templates/api/knowledge-panels/health/ingredients: allergens.tt.json
Only in /srv/off/templates/api/knowledge-panels/health/nutriscore: nutriscore_warnings.tt.json
Only in /srv/off/templates: change_password.tt.html
Only in /srv/off/templates: display_map.tt.html
Only in /srv/off/templates: display_new.tt.html
Only in /srv/off/templates: display_product.tt.html
Only in /srv/off/templates: display_product_history.tt.html
Only in /srv/off/templates: display_rev_info.tt.html
Only in /srv/off/templates: display_tag_map.tt.html
Only in /srv/off/templates: donate_banner.tt.html
Only in /srv/off/templates: ecoscore_details.tt.html
Only in /srv/off/templates: ecoscore_details_simple_html.tt.html
Only in /srv/off/templates: error_list.tt.html
Only in /srv/off/templates: export_products.tt.html
Only in /srv/off/templates: import_file_upload.tt.html
Only in /srv/off/templates: import_file_upload.tt.js
Only in /srv/off/templates: ingredients_analysis.tt.html
Only in /srv/off/templates: ingredients_analysis_details.tt.html
Only in /srv/off/templates: login.tt.html
Only in /srv/off/templates: nutrient_levels.tt.html
Only in /srv/off/templates: nutriscore_details.tt.html
Only in /srv/off/templates: nutrition_facts_table.tt.html
Only in /srv/off/templates: org_form.tt.html
Only in /srv/off/templates: org_profile.tt.html
Only in /srv/off/templates: product_image.tt.html
Only in /srv/off/templates: reset_password.tt.html
Only in /srv/off/templates: search_and_display_products.tt.html
Only in /srv/off/templates: search_form.tt.html
Only in /srv/off/templates: search_results.tt.html
Only in /srv/off/templates: spellcheck_test.tt.html
Only in /srv/off/templates: test_ingredients_analysis.tt.html
Only in /srv/off/templates: top_translators.tt.html
Only in /srv/off/templates: user_form.tt.html
Only in /srv/off/templates: user_form.tt.js
Only in /srv/off/templates: user_form2.tt.html
Only in /srv/off/templates: user_form2.tt.js
Only in /srv/off/templates: user_profile.tt.html
Only in /srv/off/templates/web/common/includes: display_blocks.tt.html
Only in /srv/off/templates/web/common/includes: display_login_register.tt.html
Only in /srv/off/templates/web/common/includes: display_my_block.tt.html
Only in /srv/off/templates/web/common/includes: donate_banner_bottom.tt.html
Only in /srv/off/templates/web/pages: login_form
Only in /srv/off/templates/web/pages/session: session.tt.html
Only in /srv/off: yarn-error.log
```
