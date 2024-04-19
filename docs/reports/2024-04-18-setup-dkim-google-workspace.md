# 2024-04-18 Setup DKIM on Google Workspace

Since I put dmarc record to `reject` policy, we had a weird bug on Google Calendar, invitations did refuse to deliver because of DKIM signature. ([bug #339](https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/339))

After digging a bit, it appears that we didn't have setup DKIM on google workspace as it should be.
Google was signing our email, but it was doing so with a generic key, which is not conventional.

So following https://support.google.com/a/answer/180504?hl=fr,
I did go to workspace admin console, gmail, and added DKIM keys for domain openfoodfacts.org, volunteers.openfoodfacts.org and ambassadors.openfoodfacts.org
I then add TXT records in OVH, and activate.

Beware, that you have to add the TXT record on the subdomains. So I have the following keys:
* `google._domainkey.openfoodfacts.org.`
* `google-volunteers._domainkey.volunteers.openfoodfacts.org`
* `google-ambassadors._domainkey.ambassadors.openfoodfacts.org`

I then tested by sending emails from my account to an external account, and verified (without having to dig in source, thanks to [dkim verifier](https://addons.thunderbird.net/fr/thunderbird/addon/dkim-verifier/))

That's all folks.