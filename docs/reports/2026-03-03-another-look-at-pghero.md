# 2026-03-03 another look at pghero

The facets being highly requested, we can try to give more performance to Postgresql,
of openfoodfacts query.

I noticed that we have free memory on moji docker prod VM.
So we may try to use more of it for postgres.


I already looked at [PGHero in the past](./2025-11-21-pghero.md)

My last statement was tha query stats was not activated.

I give another look to it. On docker prod 2 VM on osm45,
as user off, I want to see if I can activate it:
```bash
$ docker compose exec query_postgres psql -h localhost -U postgres -W query
Password: 
psql (16.8)
Type "help" for help.

query=# CREATE EXTENSION pg_stat_statements;
ERROR:  extension "pg_stat_statements" already exists
```

It seems it's already loaded.

Let's try again pghero then.
Taking instruction from my last attempt, I get it working easily.

After getting to the dashboard, I see:
```
Query Stats

Make them available by adding the following lines to postgresql.conf:

shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all

Restart the server for the changes to take effect.
```
hum, so it seems server restart is mandatory.