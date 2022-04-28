# Matomo

[Matomo](https://matomo.org/) is the web analytics platform.

Available at: https://analytics.openfoodfacts.org/

You must have a user account to access it (hopefully !). Ask for an admin to create you an account if you need it (Beware, there are personal information in the sense of GDPR like ip addresses).
Ask for it to *contact* email.

See also [Install log](./reports/2021-02-22-matomo-install.md)

## Site setup

* goto manage / websites and add a website

### GDPR

To be GDPR compliant (and user friendly) [^gdpr_ref]:

- in your Matomo Tag, you can check the option « Disable cookies » which will disable all first party tracking cookies for Matomo. [^disable_cookies]
- To ensure that you do not store the visitor IP, which is Personally Identifiable Information (PII), please go to Administration > Privacy > Anonimyze data, to enable IP anonymization, and check you have 2 bytes or 3 bytes masked from the IP address. [^ip_anon]

[^gdpr_ref]: https://fr.matomo.org/blog/2018/04/how-to-make-matomo-gdpr-compliant-in-12-steps/

[^disable_cookies]: https://fr.matomo.org/faq/general/faq_157/

[^ip_anon]: https://matomo.org/faq/general/configure-privacy-settings-in-matomo/#step-1-automatically-anonymize-visitor-ips

### In productopener

We use the `$google_analytics` variable in config to add the javascript snippet for Matomo.