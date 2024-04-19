# auto Slack invitation

**important** sadly as of 2023-03-23 slackin does not seem to work any more due to [slack API change, that wont be replaced](https://github.com/rauchg/slackin/issues/417) ([see also here](https://github.com/emedvedev/slackin-extended/issues/205), [and here](https://github.com/integrations/slack/issues/1063)).
We did replace it by a very simple static page on the [nginx reverse proxy](nginx-reverse-proxy.md) with a link that is a permanent invitation to linkedin (go to slack, invite, more details, make invitation permanent). Sadly it will only last for 400 invitations and then we will have to replace it…

## Slackin (deprecated)

https://slack.openfoodfacts.org enable users to join our slack without the need for an invitation.

It is based upon the [slackin](https://github.com/rauchg/slackin) project

This is a nodejs service in container 109 on ovh1.

Software is installed in `/home/nodejs`.

The service is managed by systemd with name `pm2-nodejs` and it's launched by [PM2](https://pm2.io/docs/runtime/guide/process-management/).

It listen on port `3000` and is accessed through the [NGINX reverse proxy](./nginx-reverse-proxy.md).
