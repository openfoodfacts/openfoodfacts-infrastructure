# Superset

Superset is an open-source data exploration and visualization platform designed to help users create interactive dashboards and reports. It supports a wide range of data sources and provides a user-friendly interface for data analysis.

Open Food Facts superset is available at: https://sql.openfoodfacts.org

## Superset functional administration

### Adding rights to a user

* Add non-registered user the possibility to see dashboards:
  * Go to "Security" -> "List Roles"
  * Edit the "Public" role
  * In the "Permissions" tab, add the "datasource access on [Other].[products]" permission
  * Save


## Superset technical administration

### Start/stop/restart the service

```bash
sudo systemctl start superset
sudo systemctl stop superset
sudo systemctl restart superset
```
Be aware that starting the service can take a while (3-5 minutes), especially if Celery workers are also configured.

### Logs

```bash
journalctl -u superset -f
```

### Update superset

**Updates absolutely need to be tested on a staging server before being applied to production.** Also, don't forget to create a snapshot of the server before updating, in case something goes wrong.

```bash
sudo su off
cd /opt/superset
source venv/bin/activate
uv pip install apache_superset --upgrade
superset db upgrade # Apply database migrations; can take several minutes
superset init       # Recreate default roles and permissions
```

### Admin password lost

You have to reset it from the command line.

```bash
sudo su off
cd /opt/superset
source venv/bin/activate
export SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py
export FLASK_APP=superset
superset fab reset-password --username admin
```

## Theming Superset

### Add OFF branding

We need to create a directory to store custom images:

```bash
sudo su off
cd /opt/superset/venv/lib/python3.11/site-packages/superset/static/assets/images/
mv favicon.png favicon-orig.png
wget https://world.openfoodfacts.org/images/favicon/off/favicon-32x32.png -O favicon.png
wget https://static.openfoodfacts.org/images/logos/off-logo-horizontal-light.svg
wget https://static.openfoodfacts.org/images/logos/off-logo-horizontal-dark.svg

# Themes are then managed in the Superset UI: Settings -> Themes
# Create two themes, one light and one dark, using these logos:
# Eg.
# {
#   "token": {
#     "brandLogoUrl": "/static/assets/images/off-logo-horizontal-light.svg",
#     "colorPrimary": "#52443d",
#     "colorInfo": "#52443d"
#   }
# }
```


### Theme customization

We have installed Superset version 6, which now have theming support:
* https://preset.io/events/superset-theming/
* https://superset.apache.org/docs/6.0.0/configuration/theming/


## Installation guide

Several installation methods are described here: https://superset.apache.org/docs/installation/installation-methods/

We choose to deploy it with PiPy, on a Debian 12 machine: https://superset.apache.org/docs/installation/pypi

### Prerequisites

Install required dependencies.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install build-essential libssl-dev libffi-dev python3-dev python3-pip libsasl2-dev libldap2-dev default-libmysqlclient-dev python3-venv
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

# Create the database and 'off' user for superset
sudo -u postgres psql <<EOF
CREATE DATABASE superset_db;
CREATE USER off WITH PASSWORD '$SUPERSET_POSTGRES_PASSWORD';
ALTER ROLE off SET client_encoding TO 'utf8';
ALTER ROLE off SET default_transaction_isolation TO 'read committed';
ALTER ROLE off SET timezone TO 'UTC';
GRANT ALL PRIVILEGES ON DATABASE superset_db TO off;
ALTER DATABASE superset_db OWNER TO off;
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

# Install is so much faster with uv
pip install uv

cat > ./requirements.txt <<EOF
apache-superset==5.0.0
marshmallow==3.26.1 # To avoid incompatibility issues, see https://github.com/apache/superset/pull/33216
# flask-limiter==3.12
psycopg2-binary
pillow
gunicorn
gevent
redis
EOF

uv pip install -r /opt/superset/requirements.txt

touch superset_config.py # Create the config file with off user permissions

# Back to root to write the config file 
exit

cat >> /opt/superset/superset_config.py <<EOF
import os

# PostgreSQL database URL
SQLALCHEMY_DATABASE_URI = "postgresql+psycopg2://off:$SUPERSET_POSTGRES_PASSWORD@localhost/superset_db"

# Secret key (for sessions and security)
SECRET_KEY = "long password here"

# Enable compression and cache
# Initial cache configuration for setup; will be replaced by Redis configuration later in this guide.
CACHE_CONFIG = {
    "CACHE_TYPE": "SimpleCache",
}

# Superset folder path
SUPERSET_HOME = "/opt/superset"

EOF

```




Then, we need to **initialize the database**.

```bash
sudo su off
cd /opt/superset
source /opt/superset/venv/bin/activate
export SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py
export FLASK_APP=superset

# The following command can take several minutes, as the following ones
superset db upgrade
```

Finish installing by running through the following commands:

```bash
# Create a password for the superset admin user
PASSWORD=$(openssl rand -base64 12)
echo "Save this password for the superset admin user: $PASSWORD"

# Create an admin user in the metadata database
superset fab create-admin --username admin --firstname Admin --lastname User --email tech@openfoodfacts.org --password $PASSWORD

# Load some data to play with
# This is optional and only useful for tests, do not uncomment for a production installation
#superset load_examples

# Create default roles and permissions
superset init

```

#### Running the development web server

To verify that everything is working, we can start the development web server:

```bash
# To start a development web server on port 8088, use -p to bind to another port
superset run -p 8088 --with-threads --reload --debugger

# Test the server by opening and ssh tunnel to access it from your local browser:
# ssh -L 8088:localhost:8088 superset # "superset" is the name of the server in your ssh config file

# To stop the server, use Ctrl+C in the terminal

# Then deactivate the virtualenv
deactivate
```

### Superset in production

The development web server should not be used in production. We have to use a WSGI server like Gunicorn:

```bash
gunicorn "superset.app:create_app()" -w 8 -k gevent --timeout 120 -b 127.0.0.1:8088

# Got the following issue, but not too annoying:
# https://github.com/apache/superset/issues/34839

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
ExecStart=/opt/superset/venv/bin/gunicorn -w 16 -k gevent --worker-connections 1000 --timeout 300 --max-requests 1000 --max-requests-jitter 50 -b 127.0.0.1:8088 "superset.app:create_app()"
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
    server_name sql.openfoodfacts.org;

    location / {
        proxy_pass http://10.12.1.111:8088; # NEEDS TO BE ADAPTED !!!!!!!!!!!!!!!!!!!!!!!!!!!!
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header Referer \$http_referer;
    }

    # Gzip compression (advised for better performance)
    gzip on;
    gzip_types text/plain text/css application/json application/javascript application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_proxied any;
    gzip_comp_level 5;
}
EOF

ln -s /etc/nginx/sites-available/superset.conf /etc/nginx/sites-enabled/

certbot --nginx -d sql.openfoodfacts.org

```

#### Configuration

The configuration file is located at `/opt/superset/superset_config.py`. This is the file to customize our Superset installation. For example, we can set up email notifications, change the default language, or configure additional authentication methods.

Added security and CSRF configuration:

```python

ENABLE_PROXY_FIX = True  # Indicates that Superset is behind a proxy

# Session configuration - Important for CSRF protection
SESSION_COOKIE_HTTPONLY = True  # Prevent JavaScript access to cookies
SESSION_COOKIE_SECURE = True  # Force HTTPS cookies (only if using HTTPS)
SESSION_COOKIE_SAMESITE = "Lax"  # Protection against CSRF attacks
PERMANENT_SESSION_LIFETIME = 86400  # 24 hours in seconds
SESSION_COOKIE_NAME = "superset_session"

# CSRF Configuration - Important for forms and API calls
WTF_CSRF_ENABLED = True
WTF_CSRF_TIME_LIMIT = None  # Don't expire CSRF tokens
WTF_CSRF_SSL_STRICT = False  # Allow behind reverse proxy

# Public role configuration (important for CSRF with anonymous users)
PUBLIC_ROLE_LIKE = "Gamma"

# Talisman (security headers) - disable if causing issues
TALISMAN_ENABLED = False

```


After making changes to the configuration file, restart the Superset service to apply the changes:

```bash
sudo systemctl restart superset
```

#### Keycloak Authentication (OAuth2/OIDC)

Superset can integrate with Keycloak for single sign-on authentication using OAuth2/OIDC.

This setup is build upon different online resources, including:
- https://blog.devgenius.io/apache-superset-integration-with-keycloak-3571123e0acf
- Github copilot help
- Superset own AI: https://superset.apache.org/

First, install the required Python packages:

```bash
sudo su off
cd /opt/superset
source venv/bin/activate
uv pip install Authlib
deactivate
exit
```

**Configure Keycloak Client:**

1. In your Keycloak admin console (https://auth.openfoodfacts.org), go to your realm (e.g., `openfoodfacts`)
2. Navigate to **Clients** → **Create client**
3. Configure the client:
   - **Client ID**: `superset`
   - **Client Protocol**: `openid-connect`
   - **Access Type**: `confidential`
4. **CRITICAL**: Add valid redirect URIs (both variants):
   - `https://sql.openfoodfacts.org/oauth-authorized/keycloak`
   - `https://sql.openfoodfacts.org/oauth-authorized/keycloak/`
   - Add wildcard for development if needed: `https://sql.openfoodfacts.org/*`
5. Set **Valid Post Logout Redirect URIs**: `https://sql.openfoodfacts.org/*`
6. Set **Web Origins**: `https://sql.openfoodfacts.org`
7. Save the client configuration
8. Go to the **Credentials** tab and note the **Client Secret**

**Add to `superset_config.py`:**

```python
from flask_appbuilder.security.manager import AUTH_OAUTH

# Enable OAuth authentication (supports both OAuth and DB authentication)
AUTH_TYPE = AUTH_OAUTH

# Keycloak OAuth configuration
OAUTH_PROVIDERS = [
    {
        'name': 'keycloak',
        'icon': 'fa-key',
        'token_key': 'access_token',
        'remote_app': {
            'client_id': 'superset',  # Your Keycloak client ID
            'client_secret': 'YOUR_CLIENT_SECRET',  # Your Keycloak client secret
            'client_kwargs': {
                'scope': 'openid email profile'
            },
            'api_base_url': 'https://auth.openfoodfacts.org/realms/openfoodfacts/',
            'access_token_url': 'https://auth.openfoodfacts.org/realms/openfoodfacts/protocol/openid-connect/token',
            'authorize_url': 'https://auth.openfoodfacts.org/realms/openfoodfacts/protocol/openid-connect/auth',
            'server_metadata_url': 'https://auth.openfoodfacts.org/realms/openfoodfacts/.well-known/openid-configuration',
        }
    }
]

# Custom security manager for Keycloak user mapping
from superset.security import SupersetSecurityManager

class CustomSecurityManager(SupersetSecurityManager):
    def oauth_user_info(self, provider, response=None):
        if provider == 'keycloak':
            # Get user info from Keycloak using the correct endpoint
            import logging
            log = logging.getLogger(__name__)
            
            try:
                # The userinfo endpoint is relative to api_base_url
                # So we need to use the full path: protocol/openid-connect/userinfo
                me = self.appbuilder.sm.oauth_remotes[provider].get(
                    'protocol/openid-connect/userinfo'
                )
                data = me.json()
                
                # Log the received data for debugging
                log.info(f"Keycloak user data: {data}")
                
                # Handle error responses
                if 'error' in data:
                    log.error(f"Keycloak error: {data}")
                    return {}
                
                return {
                    'username': data.get('preferred_username', ''),
                    'email': data.get('email', ''),
                    'first_name': data.get('given_name', ''),
                    'last_name': data.get('family_name', ''),
                }
            except Exception as e:
                log.error(f"Error getting Keycloak user info: {e}")
                return {}

CUSTOM_SECURITY_MANAGER = CustomSecurityManager

# IMPORTANT: Enable user auto-registration (required for first-time Keycloak users)
AUTH_USER_REGISTRATION = True
AUTH_USER_REGISTRATION_ROLE = "Gamma"  # Default role for new users

# Allow users to self-register through OAuth
AUTH_ROLE_ADMIN = "Admin"
AUTH_ROLE_PUBLIC = "Public"

# Optional: Role mapping from Keycloak roles
# AUTH_ROLES_MAPPING = {
#     "superset_admin": ["Admin"],
#     "superset_alpha": ["Alpha"],
#     "superset_gamma": ["Gamma"],
# }
```

**Important notes:**
- Replace `YOUR_CLIENT_SECRET` with your actual Keycloak client secret from the Credentials tab
- Adjust the Keycloak URLs to match your Keycloak instance (realm name, domain)
- **The redirect URI in Keycloak must EXACTLY match**: `https://sql.openfoodfacts.org/oauth-authorized/keycloak`
- Users will be automatically created on first login if `AUTH_USER_REGISTRATION = True`

**Troubleshooting "Invalid parameter: redirect_uri" error:**

If you get this error, check the following:

1. **Verify redirect URI in Keycloak:**
   - Go to Keycloak admin → Clients → `superset` → Settings
   - Ensure "Valid Redirect URIs" includes: `https://sql.openfoodfacts.org/oauth-authorized/keycloak`
   - Try adding both with and without trailing slash: 
     - `https://sql.openfoodfacts.org/oauth-authorized/keycloak`
     - `https://sql.openfoodfacts.org/oauth-authorized/keycloak/`
   - Or use wildcard: `https://sql.openfoodfacts.org/*`

2. **Check the OAuth provider name:**
   - The name in `OAUTH_PROVIDERS` must match the callback URL
   - If `name: 'keycloak'`, the redirect URI will be `/oauth-authorized/keycloak`
   - They must match exactly (case-sensitive)

3. **Verify Superset can reach Keycloak:**
   ```bash
   # Test from the Superset server
   curl -v https://auth.openfoodfacts.org/realms/openfoodfacts/.well-known/openid-configuration
   ```

4. **Check Superset logs for details:**
   ```bash
   sudo journalctl -u superset -f
   ```

**Troubleshooting "Invalid login. Please try again." error:**

If authentication with Keycloak works but you get "Invalid login" in Superset:

1. **Check Superset logs immediately after failed login:**
   ```bash
   sudo journalctl -u superset -n 100
   ```
   Look for errors related to user creation or OAuth

2. **Verify user info is being received from Keycloak:**
   - The logs should show "Keycloak user data: {...}" if the CustomSecurityManager is working
   - Check that Keycloak is returning `preferred_username`, `email`, `given_name`, `family_name`

3. **Ensure AUTH_USER_REGISTRATION is enabled:**
   - Must be `True` in `superset_config.py` for auto-creating users
   - Check that `AUTH_USER_REGISTRATION_ROLE = "Gamma"` is set

4. **Verify Keycloak user has required fields:**
   - In Keycloak admin, check that your user has:
     - Email address set
     - First name and last name set
     - Username set
   - Go to Keycloak → Users → [your user] → Attributes

5. **Test the userinfo endpoint manually:**
   ```bash
   # First, get an access token (you'll need to extract it from browser dev tools during login)
   # Then test the userinfo endpoint:
   curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
     https://auth.openfoodfacts.org/realms/openfoodfacts/protocol/openid-connect/userinfo
   ```

6. **Try creating the user manually first:**
   ```bash
   sudo su off
   cd /opt/superset
   source venv/bin/activate
   export SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py
   export FLASK_APP=superset
   
   # Create a user with the same email/username as in Keycloak
   superset fab create-user \
     --username your_keycloak_username \
     --firstname YourFirstName \
     --lastname YourLastName \
     --email your@email.com \
     --role Gamma \
     --password temporary_password
   
   deactivate
   exit
   ```
   Then try logging in with Keycloak again

7. **Check database permissions:**
   ```bash
   # Ensure Superset can write to its database
   sudo -u postgres psql -d superset_db -c "SELECT * FROM ab_user LIMIT 1;"
   ```

8. **Enable debug logging:**
   Add to `superset_config.py`:
   ```python
   import logging
   logging.basicConfig(level=logging.DEBUG)
   LOG_LEVEL = "DEBUG"
   ```
   Then restart and check logs again

**How to login with the admin account after enabling Keycloak:**

By default, when `AUTH_TYPE = AUTH_OAUTH` is set, only the OAuth login button is shown. **Unfortunately, Superset doesn't support showing both forms simultaneously in a simple way.**

**Best solution: Use a direct login URL for admin access**

Access the database login form directly by going to:
```
https://sql.openfoodfacts.org/login/?next=
```

Or temporarily switch authentication modes when you need admin access:

**Method 1: Temporarily switch to DB auth (Recommended for admin access):**

1. Edit `/opt/superset/superset_config.py`:
   ```bash
   sudo nano /opt/superset/superset_config.py
   ```

2. Comment out OAuth and enable DB auth:
   ```python
   from flask_appbuilder.security.manager import AUTH_DB
   AUTH_TYPE = AUTH_DB  # Temporarily for admin login
   
   # Temporarily comment out OAuth config:
   # AUTH_TYPE = AUTH_OAUTH
   # OAUTH_PROVIDERS = [...]
   # CUSTOM_SECURITY_MANAGER = CustomSecurityManager
   ```

3. Restart:
   ```bash
   sudo systemctl restart superset
   ```

4. Login with admin, do your administrative work

5. Change back to OAuth and restart when done

**Method 2: Create admin account in Keycloak**

The better long-term solution is to give your admin user OAuth access:
- Login to Keycloak with your account
- In Superset, grant your OAuth user Admin role:
  ```bash
  sudo su off
  cd /opt/superset
  source venv/bin/activate
  export SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py
  export FLASK_APP=superset
  
  # List users to find your OAuth username
  superset fab list-users
  
  # Add Admin role to your Keycloak user
  superset fab add-role-permission --username your_keycloak_username --role Admin
  
  deactivate
  exit
  ```

**Method 3: Reset the admin password** (for emergency access):
```bash
sudo su off
cd /opt/superset
source venv/bin/activate
export SUPERSET_CONFIG_PATH=/opt/superset/superset_config.py
export FLASK_APP=superset
superset fab reset-password --username admin
deactivate
exit
```
Then temporarily switch to DB auth to use it.

**Recommended approach:** Grant Admin role to your Keycloak account so you can manage everything through OAuth:
- Users can login with Keycloak (OAuth button)
- Users can login with username/password (the form below the OAuth button)
- The admin account uses database authentication

Restart Superset after configuration changes:

```bash
sudo systemctl restart superset
```

Users will now see a "Login with keycloak" button on the login page.

#### Redis installation for caching (not yet installed)

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

## Reading Parquet Files

Superset can read Parquet files using DuckDB, which provides excellent performance for analytical queries on Parquet files.

#### Install DuckDB Support

```bash
sudo su off
cd /opt/superset
source venv/bin/activate
uv pip install duckdb-engine
deactivate
exit
```

DuckDB can query Parquet files directly as if they were database tables.

**Setup:**

```bash
# Create a DuckDB database file
sudo su off
cd /opt/superset
source venv/bin/activate

# Create a Python script to set up your DuckDB database
cat > setup_duckdb.py <<'EOF'
import duckdb

# Connect to DuckDB (creates file if it doesn't exist)
con = duckdb.connect('/opt/superset/data/analytics.duckdb')

# Create views for your Parquet files
con.execute("""
    CREATE VIEW products AS 
    SELECT * FROM read_parquet('/opt/superset/data/food.parquet')
""")

# Verify
print(con.execute("SHOW TABLES").fetchall())
con.close()
EOF

python setup_duckdb.py
deactivate
exit
```

Then in Superset:
1. [Add database connection](https://sql.openfoodfacts.org/databaseview/list/) (select "other" and enter the following in the SQLAlchemy URI): `duckdb:////opt/superset/data/analytics.duckdb`
2. Your view `products` will appear as a regular table
3. Create datasets and charts as normal
4. In SQL Lab, you can query Parquet files directly:
   ```sql
   -- Query a single Parquet file
   SELECT * FROM read_parquet('data/file.parquet');
   
   -- Query multiple Parquet files with wildcards
   SELECT * FROM read_parquet('data/*.parquet');
   
   -- Create a view for easier access
   CREATE VIEW my_data AS 
   SELECT * FROM read_parquet('data/*.parquet');
   ```

Eg. in the [SQL Lab](https://sql.openfoodfacts.org/sqllab/), you can run:

```sql
SELECT * FROM read_parquet('data/food.parquet');
```


**Performance tips:**
- DuckDB can handle hundreds of GBs of Parquet files efficiently
- Use partitioned Parquet files for better query performance
- DuckDB automatically uses column pruning and predicate pushdown
- Consider creating aggregated views for frequently-used queries


## Common Warnings and Issues

### Warning: "Unable to load SQLAlchemy dialect metricflow: No module named 'python_graphql_client'"

This is a harmless warning about an optional database driver that's not installed. MetricFlow is a semantic layer for dbt, and unless you're using it, you can safely ignore this warning.

**To suppress it (optional):**
```bash
sudo su off
cd /opt/superset
source venv/bin/activate
uv pip install python-graphql-client
deactivate
exit
sudo systemctl restart superset
```

Or just ignore it - it doesn't affect Superset's functionality.

### Other common warnings you can ignore:
- `Unable to load SQLAlchemy dialect [dialect_name]` - These are warnings about optional database drivers
- Only install drivers for databases you actually want to connect to

