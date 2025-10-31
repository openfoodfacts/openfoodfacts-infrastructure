# Superset

Several installation methods are described here: https://superset.apache.org/docs/installation/installation-methods/

We choose to deploy it with PiPy, on a Debian 12 machine: https://superset.apache.org/docs/installation/pypi

### Prerequisites

Install required dependencies.

```bash
sudo apt install build-essential libssl-dev libffi-dev python-dev python-pip libsasl2-dev libldap2-dev default-libmysqlclient-dev
```

Create the user: we use a specific user to deploy this app.

```bash
sudo useradd off --create-home --user-group --shell /bin/bash
```

Create and choose the path where the app is installed.

```bash
mkdir -p /opt/superset
chown -R off:off /opt/superset
```

Configure email if necessary: https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/docs/mail.md#postfix-configuration

Firstly we have to configure a database, at least useful for superset's metadata. Sqlite is good for tests, but we prefer to start directly with PostgreSQL, recommended in a production environment.

### PostreSQL installation for superset

```bash
apt install -y postgresql postgresql-contrib libpq-dev

# Create a password for the 'postgres' user
SUPERSET_POSTGRES_PASSWORD=$(openssl rand -base64 12)
echo "Save this password for the 'postgres' user: $SUPERSET_POSTGRES_PASSWORD"

# Verify it does work
systemctl status postgresql
sudo -u postgres psql <<EOF
CREATE DATABASE superset_db;
CREATE USER off WITH PASSWORD '$SUPERSET_POSTGRES_PASSWORD';
ALTER ROLE off SET client_encoding TO 'utf8';
ALTER ROLE off SET default_transaction_isolation TO 'read committed';
ALTER ROLE off SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE superset_db TO off;
EOF
```

### Superset installation

The git repo to manage server configuration should have been deployed:
https://github.com/openfoodfacts/openfoodfacts-infrastructure/blob/develop/docs/explain-server-config-in-git.md#ansible-role

```bash
sudo su off
cd /opt/superset

python3 -m venv venv
source venv/bin/activate

pip install apache_superset

export SUPERSET_SECRET_KEY=$(openssl rand -base64 42)

export FLASK_APP=superset

cat >> /etc/systemd/system/superset.service<<EOF
import os

# PostgreSQL database URL
SQLALCHEMY_DATABASE_URI = "postgresql+psycopg2://off:$SUPERSET_POSTGRES_PASSWORD@localhost/superset_db"

# Secret key (for sessions and security)
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY')

# Enable compression and cache
CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
}

# Superset folder path
SUPERSET_HOME = "/opt/superset"

EOF
```




Then, we need to **initialize the database**.

```bash
export SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py
superset db upgrade
```

Finish installing by running through the following commands:

```bash
# Create a password for the 'postgres' user
PASSWORD=$(openssl rand -base64 12)
echo "Save this password for the superset admin user: $PASSWORD"

# Create an admin user in the metadata database
superset fab create-admin --username admin --firstname Admin --lastname User --email tech@openfoodfacts.org --password $PASSWORD

# Load some data to play with (optional?)
superset load_examples

# Create default roles and permissions
superset init

```

#### Running the development web server

To verify that everything is working, we can start the development web server:

```bash
# To start a development web server on port 8088, use -p to bind to another port
superset run -p 8088 --with-threads --reload --debugger

# To stop the server, use Ctrl+C in the terminal

# Then deactivate the virtualenv
deactivate
```

### Superset in production

The development web server should not be used in production. We have to use a WSGI server like Gunicorn:

```bash
gunicorn "superset.app:create_app()" -w 8 -k event --timeout 120 -b 127.0.0.1:8088
```

It shouldn't be run directly, so we will create a systemd service to manage it.

#### Configure systemd

```bash
su root
cat > /etc/systemd/system/superset.service<<EOF
[Unit]
Description=Apache Superset
After=network.target

[Service]
User=off
Group=off
WorkingDirectory=/opt/superset
Environment="SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py"
ExecStart=/opt/superset/venv/bin/gunicorn -w 8 -k gevent --timeout 120 -b 127.0.0.1:8088 "superset.app:create_app()"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable superset
sudo systemctl start superset
```

#### Configure nginx

```bash
su root

cat > /etc/nginx/sites-available/superset.conf<<EOF
server {
    listen 80;
    server_name superset.openfoodfacts.org;

    location / {
        proxy_pass http://127.0.0.1:8088; # NEEDS TO BE ADAPTED !!!!!!!!!!!!!!!!!!!!!!!!!!!!
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Gzip compression (advised for better performance)
    gzip on;
    gzip_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_proxied any;
    gzip_comp_level 5;
}
EOF

ln -s /etc/nginx/sites-available/superset.conf /etc/nginx/sites-enabled/

certbot --nginx -d superset.openfoodfacts.org

```

#### Configuration

The configuration file is located at `/opt/superset/superset_config.py`. This is the file to customize our Superset installation. For example, we can set up email notifications, change the default language, or configure additional authentication methods.

Added security:

```python
ENABLE_PROXY_FIX = True  # Indicates that Superset is behind a proxy
SESSION_COOKIE_SECURE = True  # Force HTTPS cookies
SESSION_COOKIE_SAMESITE = "Lax"  # Protection against CSRF attacks
```


After making changes to the configuration file, restart the Superset service to apply the changes:

```bash
sudo systemctl restart superset
```

#### Redis installation for caching

Install Redis and Python bindings:

```bash
sudo apt install -y redis-server
sudo systemctl enable redis
sudo systemctl start redis
source /opt/superset/venv/bin/activate
pip install redis
```

Add the following lines to the `superset_config.py` file:

```python
# Redis configuration for caching
CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300, # seconds (5 minutes)
    'CACHE_KEY_PREFIX': 'superset_',
    'CACHE_REDIS_URL': 'redis://localhost:6379/0',
}

# Cache query results
DATA_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 600,  # 10 min TTL for queries
    'CACHE_KEY_PREFIX': 'superset_results_',
    'CACHE_REDIS_URL': 'redis://localhost:6379/1'
}

# Optional: thumbnail cache (charts and dashboards)
THUMBNAIL_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 3600,  # 1 hour
    'CACHE_KEY_PREFIX': 'superset_thumbnails_',
    'CACHE_REDIS_URL': 'redis://localhost:6379/2'
}

# Optional: Cache for complex metadata operations
FILTER_STATE_CACHE_CONFIG = {
    'CACHE_TYPE': 'RedisCache',
    'CACHE_DEFAULT_TIMEOUT': 300,
    'CACHE_KEY_PREFIX': 'superset_filter_state_',
    'CACHE_REDIS_URL': 'redis://localhost:6379/3'
}
```

#### Celery installation for async queries and alerts

This needs to be evaluated.

Install Celery and Python bindings:

```bash
source /opt/superset/venv/bin/activate
pip install celery[redis] flower
```

Add the following lines to the `superset_config.py` file:

```python
# Celery configuration -- see: https://superset.apache.org/docs/configuration/async-queries-celery/
from celery.schedules import crontab
class CeleryConfig:
    BROKER_URL = 'redis://localhost:6379/4' # message queue
    CELERY_IMPORTS = ('superset.sql_lab', )  # 
    CELERY_RESULT_BACKEND = 'redis://localhost:6379/5'
    CELERY_ANNOTATIONS = {'tasks.add': {'rate_limit': '10/s'}}
    CELERYBEAT_SCHEDULE = {
        'reports.scheduler': {
            'task': 'superset.reports.scheduler',
            'schedule': crontab(minute='*/5'),  # every 5 minutes
        },
    }
CELERY_CONFIG = CeleryConfig

FEATURE_FLAGS = {
    'ENABLE_CELERY': True,
    'ENABLE_ALERTS': True,
    'ENABLE_SCHEDULED_QUERIES': True,
}
```

#### Running Celery workers
To run the Celery worker and beat scheduler, create systemd service files:

```bash
su root
cat > /etc/systemd/system/superset-celery.service<<EOF
[Unit]
Description=Superset Celery Worker
After=network.target

[Service]
User=off
Group=off
WorkingDirectory=/opt/superset
Environment="SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py"
ExecStart=/opt/superset/venv/bin/celery worker --app=sup
erset.tasks.celery_app:app --loglevel=info
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable superset-celery
systemctl start superset-celery

cat > /etc/systemd/system/superset-celery-beat.service<<EOF
[Unit]
Description=Superset Celery Beat Scheduler
After=network.target

[Service]
User=off
Group=off
WorkingDirectory=/opt/superset
Environment="SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py"
ExecStart=/opt/superset/venv/bin/celery beat --app=sup
erset.tasks.celery_app:app --loglevel=info
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable superset-celery-beat
systemctl start superset-celery-beat

```

