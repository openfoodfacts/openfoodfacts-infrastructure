# Elasticsearch not running on Zammad

Date: 2022-03-03


## Problem

I wanted to [Set up ES for Zammad](https://github.com/openfoodfacts/openfoodfacts-infrastructure/issues/91)

After having access to the machine (which up to now is gracefully hosted by CQuest), I verify, as told by CQuest, that elasticsearch was installed.

The problem was the elasticsearch service was not running, according to `systemctl status elasticsearch`.

`journalctl -r -u elasticsearch`  
shows this error:  
`Failed to start elasticsearch due to a fatal signal received by control process (code=killed, signal=9/KILL)`

## Solution

After searching about in various directions, it reminds me of a OOMKill situation. Although we didn't have a OOMKill message in `/var/log/syslog` because this is an LXC container, so OOMKill happens in the guest.

As I look into `/etc/elasticsearch/jvm.options` I've seen that by default it handles memory alone by looking at available memory.

Being in an LXC container, it sees more memory than the container is allowed to take. Hence the kill situation.

Thus I decided to fix the heap size manually. I created a file `/etc/elasticsearch/jvm.options.d/memory.options` [^options] with:

```
-Xms300m
-Xmx300m
```

After a `systemctl start elasticsearch`, elasticsearch was up.

[^options]: in fact I was induced in error because in `jvm.options` the mandatory `.options` extension was not cited, so I first created a file with no extension and it did not work (but no log could tell me that). Reading [online doc](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/advanced-configuration.html#set-jvm-options) I sort this out. The problem is  [already fixed in elasticsearch repos](https://github.com/elastic/elasticsearch/commit/3aeac89466f87c992f26a3885903264a1945f561)

## Resolution 2 - zammad messed up

I first had a hardtime figuring out how zammad was running.

The real services in `/etc/systemd/system/` are the one with a `-1` in their name (others are just sleep commands, they act as placeholders to handle dependencies, I guess). But the executable was not there !

This was because I unadvertantly de-installed it, while trying to solve elasticsearch issue (where I did a uninstall / reinstall of elasticsearch). I did not see it was also de-installing zammad :-/

Hopefully I did not purge, and an `apt install zammad` solved the issue !


## Finish ES integration

Following https://docs.zammad.org/en/latest/install/elasticsearch.html, I wanted to verify settings:

```
$ zammad run rails r 'print Setting.get("es_index") + "\n"'
zammad
```

I reindex everything using  
`zammad run rake searchindex:rebuild`  
as indicated on [zammad issue 1630](https://github.com/zammad/zammad/issues/1630#issuecomment-344864858)

It failed with:
```
rake aborted!
Unable to send Ticket.find(33).search_index_update_backend backend: #<RuntimeError: Unable to process post request to elasticsearch URL 'http://localhost:9200/zammad_production_ticket/_doc/33?pipeline=zammad116611039594'. Elasticsearch is not reachable, probably because it's not running or even installed.

Response:
#<UserAgent::Result:0x0000563cf7686228 @success=false, @body=nil, @data=nil, @code=0, @content_type=nil, @error="#<Errno::ECONNREFUSED: Failed to open TCP connection to localhost:9200 (Connection refused - connect(2) for \"localhost\" port 9200)>", @header=nil>
```

Indeed `systemctl status elasticsearch` shows me it failed. Due to `Terminating due to java.lang.OutOfMemoryError: Java heap space`

I edit `/etc/elasticsearch/jvm.options.d/memory.options` to give more memory:

```
-Xms600m
-Xmx600m
```

Then relaunched:

`zammad run rake searchindex:rebuild`

Finally it works !

## Lessons learned

This Elasticsearch memory problem is a recurring one ! In this case it was hard to spot at first sight. But this is always a lead to investigate on a hard kill of an Elasticsearch instance.

Be prudent when doing `apt remove` to verify you aren't removing something else ! 😓