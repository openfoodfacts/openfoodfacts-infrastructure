# MediaWiki Composer updates failing: Gerrit 403

**Date**: 2026-10-21

**Authors**: @hangy

**Status**: Complete

**Summary**: `composer update` on the MediaWiki installs (openfoodfacts.org wiki and staging) failed while installing extensions hosted on Wikimedia Gerrit (e.g. `mediawiki/pluggable-auth`), aborting with `Authentication required (gerrit.wikimedia.org):` and prompting for a username/password.

**Impact**: MediaWiki core and extension updates (including security updates) could not be installed on PCT 104 (wiki) and PCT 142 (wiki-staging). No user-facing outage, but the wiki deployments were stuck on outdated versions.

**Root Causes**: Wikimedia enforces a user-agent policy on `gerrit.wikimedia.org`; requests without an identifying user-agent are rejected with HTTP 403 by the Varnish layer in front of Gerrit. Composer/Git's default user-agent (`git/2.x`) does not comply, and the 403 is misreported by Composer as an authentication requirement. Additionally, the fix (setting `http.userAgent` via `git config --global`) was initially applied for the wrong user: Composer on the wiki hosts runs as `www-data`, but the config was written to root's `~/.gitconfig`, so the error persisted until it was set for `www-data`.

**Trigger**: Gerrit rejecting requests without an identifying user-agent. The error appeared when running `composer update` on the affected hosts.

## Resolution

- **Short term:** set an identifying Git user-agent for the user that runs Composer:
  ```bash
  runuser -u www-data -- git config --global http.userAgent "OpenFoodFacts Wiki (contact@openfoodfacts.org)"
  ```
- **Long term:** document that all wiki maintenance commands (`git`, `composer`, `php maintenance/…`) must be run as `www-data`, and add the user-agent config to wiki host provisioning.

**Detection**: Manual: `composer update` failed interactively. Also worth verifying after the fix:
```bash
curl -sI -A "OpenFoodFacts Wiki (contact@openfoodfacts.org)" https://gerrit.wikimedia.org/r/mediawiki/extensions/PluggableAuth
```

## Action Items

|**Action Item**|**Type**|**Owner**|**Status**|
| :- | :- | :- | :- |
|Set `http.userAgent` for `www-data` on PCT 142 (wiki-staging)|mitigate|@hangy|**DONE**|
|Set `http.userAgent` for `www-data` on PCT 104 (wiki)|mitigate|@hangy|**DONE**|

## Lessons Learned

### What went well

- Gerrit itself was never broken or rate-limiting us — the cause was local and quick to fix once understood.
- Debugging with `git ls-remote` directly isolated the problem to the Composer/Git user mismatch.

### What went wrong

- Composer's error message (`Authentication required`) was misleading; entering credentials could never have fixed it.
- The first fix was applied for the wrong user (`root` instead of `www-data`), costing an extra debugging round.
- No runbook entry existed for which user MediaWiki maintenance must run as.

### Where we got lucky

- Only dependency updates were blocked; the wiki itself kept running on the existing code.

### What we learned

- Wikimedia Gerrit requires an identifying user-agent ([WMF user-agent policy](https://foundation.wikimedia.org/wiki/Legal:Responsible_Use_Policy)); set `http.userAgent` in Git for any host pulling from Gerrit.
- `git config --global` is per-user: when Composer runs as `www-data`, the config must be set for `www-data`, e.g. via `runuser -u www-data -- git config --global …`.

## Timeline

#### 2026-10-21 (CEST)

- `composer update` on wiki-staging fails with `Authentication required (gerrit.wikimedia.org):`.
- Identified the cause via Sam Wilson's write-up: Gerrit/Varnish returning 403 for non-identifying user-agents.
- Set `http.userAgent` globally — initially as root, error persisted.
- Verified with `git ls-remote` as root (working) → narrowed it down to the Composer runtime user.
- **FIX** — set the user-agent for `www-data`: `runuser -u www-data -- git config --global http.userAgent "OpenFoodFacts Wiki (contact@openfoodfacts.org)"` → `composer update` succeeds on wiki-staging.
- Same change implemented for PCT 104 (wiki).
