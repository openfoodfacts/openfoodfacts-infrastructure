# 2026-08-10 Superset upgrade issue resulting in no dashboard working

Investigated by Stéphane on 2026-08-10.

Users reported on 2026-08-09 that Superset dashboards were not working.

## Symptoms

Pages like <https://sql.openfoodfacts.org/api/v1/dashboard/38/charts> resulted in a 500 internal server error, but without much detail in the response:

```json
{"message":"Fatal error"}
```

In the PostgreSQL logs of the superset container, I see errors like:

```
2026-08-10 11:55:37.401 CEST [116136] off@superset_db ERROR:  column tables.currency_code_column does not exist at character 756
```

## Analysis

Checked where superset is installed, using <https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/ansible/inventory.production.ini>

```
superset proxmox_ct_id=111 proxmox_node="hetzner-02"
```

Checked logs in `/var/log`, nothing interesting in `/var/log/superset` but errors in `/var/log/postgresql/postgresql-15-main.log`

I don't know superset, so I asked ChatGPT that suggested that the Superset metadata database schema was behind the installed Superset version. Commands below were suggested by ChatGPT.

The superset installation is a Python virtualenv installation:

```
/opt/superset/venv/bin/superset
```

Superset is running as Unix user `off`, managed by systemd:

```
superset.service
superset-celery.service
superset-celery-beat.service
superset-flower.service
```

Checked installed version:

```sh
/opt/superset/venv/bin/superset version
```

Result:

```text
Superset 6.1.0
Pending database migrations: run 'superset db upgrade'
```

The message "Pending database migrations: run 'superset db upgrade'" indicates that the Superset metadata database is out of date relative to the installed Superset code.

Checked migration state:

```sh
/opt/superset/venv/bin/superset db current
```

Result:

```text
c233f5365c9e
```

```sh
/opt/superset/venv/bin/superset db heads
```

Result:

```text
4b2a8c9d3e1f (head)
```

This confirmed that the metadata database was missing migrations.

Before modifying the database, a PostgreSQL custom-format backup was created:

```sh
sudo -u postgres pg_dump -Fc superset_db > /root/superset_db_20260810_121953.dump
```

The initial attempt to run the migration failed with:

```text
Refusing to start due to insecure SECRET_KEY
```

```sh
root@superset:/var/log/postgresql# sudo -u off /opt/superset/venv/bin/superset db upgrade
```

```text
--------------------------------------------------------------------------------
                                    WARNING
--------------------------------------------------------------------------------
A Default SECRET_KEY was detected, please use superset_config.py to override it.
Use a strong complex alphanumeric string and use a tool to help you generate 
a sufficiently random sequence, ex: openssl rand -base64 42 
For more info, see: https://superset.apache.org/docs/configuration/configuring-superset#specifying-a-secret_key
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Refusing to start due to insecure SECRET_KEY
```

But the secret key was correctly set in `/opt/superset/superset_config.py`, and the systemd service was running fine. The issue was that the manual invocation of the superset CLI did not inherit the environment variable `SUPERSET_CONFIG_PATH` that points to the configuration file.

The systemd services explicitly set:

```
Environment="SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py"
```

but a manual `sudo -u off ...` invocation did not inherit this systemd environment. Without `SUPERSET_CONFIG_PATH`, the CLI did not load the local configuration and therefore fell back to Superset's default insecure SECRET_KEY.

The migration was successfully run using the same configuration as the systemd service:

```sh
sudo -u off env SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py \
    /opt/superset/venv/bin/superset db upgrade
```

The important migration output was:

```text
Running upgrade c233f5365c9e -> x2s8ocx6rto6, Expand username field to 128 chars
Running upgrade x2s8ocx6rto6 -> a9c01ec10479, add_datetime_format_to_table_columns
Running upgrade a9c01ec10479 -> f5b5f88d8526, fix_form_data_string_in_query_context
Running upgrade f5b5f88d8526 -> 9787190b3d89, add currency column support
Adding column currency_code_column to table tables...
Running upgrade 9787190b3d89 -> 4b2a8c9d3e1f, Create tasks and task_subscriber tables for Global Task Framework (GTF)
```

The migration completed successfully.

## Resolution

The Superset metadata database was out of date relative to the installed Superset 6.1.0 code. The migration adding `tables.currency_code_column` had not been applied, causing Superset's chart/dashboard API queries to fail with PostgreSQL UndefinedColumn errors.

Running the pending migrations brought the metadata database to migration head `4b2a8c9d3e1f` and created the missing `currency_code_column`.

Superset services were then restarted and dashboards/API calls worked again.

Note: I did not investigate why the Superset upgrade to 6.1.0 did not automatically run the database migrations, but it is possible that the upgrade was done manually without running `superset db upgrade` afterward.
