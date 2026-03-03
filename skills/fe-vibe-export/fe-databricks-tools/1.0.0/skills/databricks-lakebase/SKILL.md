---
name: databricks-lakebase
description: Create, configure, and query Lakebase Postgres databases using CLI and code
---

# Databricks Lakebase Skill

Create and manage Lakebase Postgres databases on Databricks. Lakebase provides fully-managed PostgreSQL with automatic scaling, branching, and Unity Catalog integration.

## Prerequisites

1. **FE-VM Workspace** - Required for Lakebase
   - Use `/databricks-fe-vm-workspace-deployment` skill to get a workspace
   - Need "serverless" workspace type for Lakebase support

2. **Databricks CLI** - Version 0.229.0+
   - Authenticate: `databricks auth login --host <workspace-url> --profile <profile-name>`

3. **psql client** (optional but recommended)
   - macOS: `brew install postgresql@16`
   - Linux: `apt install postgresql-client`

## Lakebase Tiers

Lakebase has two tiers:

| Feature | Provisioned Tier | Autoscaling Tier |
|---------|-----------------|------------------|
| CLI Support | Full (`databricks database`) | Limited (UI-based) |
| Capacity | CU_1, CU_2, CU_4, CU_8 | 0.5-32 CU (auto) |
| Scale-to-Zero | No | Yes |
| Branching | Via PITR | Full branching |
| Read Replicas | Yes | Yes |

This skill focuses on the **Provisioned Tier** which has full CLI support.

## Quick Reference: CLI Commands

```bash
# List all instances
databricks database list-database-instances -p PROFILE

# Get instance details
databricks database get-database-instance INSTANCE_NAME -p PROFILE

# Create instance
databricks database create-database-instance INSTANCE_NAME \
  --capacity=CU_1 \
  --enable-pg-native-login \
  -p PROFILE

# Update instance
databricks database update-database-instance INSTANCE_NAME "capacity" \
  --capacity=CU_2 \
  -p PROFILE

# Delete instance
databricks database delete-database-instance INSTANCE_NAME -p PROFILE

# Connect with psql
databricks psql INSTANCE_NAME -p PROFILE
```

## Creating a Lakebase Instance

### Step 1: Create the Instance

```bash
# Create with minimum capacity (CU_1)
databricks database create-database-instance my-lakebase \
  --capacity=CU_1 \
  --enable-pg-native-login \
  --no-wait \
  -p PROFILE
```

**Capacity Options:**
- `CU_1` - 1 Compute Unit (~2GB RAM) - Development/Testing
- `CU_2` - 2 Compute Units (~4GB RAM) - Light production
- `CU_4` - 4 Compute Units (~8GB RAM) - Production
- `CU_8` - 8 Compute Units (~16GB RAM) - Heavy production

**Additional Options:**
- `--enable-pg-native-login` - Allow password-based authentication
- `--retention-window-in-days INT` - PITR retention (default: 7 days)
- `--node-count INT` - Number of nodes (1 primary + N-1 secondaries)
- `--enable-readable-secondaries` - Enable read replicas
- `--no-wait` - Don't wait for instance to be available

### Step 2: Wait for Instance to be Available

```bash
# Check status
databricks database get-database-instance my-lakebase -p PROFILE | jq '.state'

# Wait for AVAILABLE state (takes 2-5 minutes)
while [ "$(databricks database get-database-instance my-lakebase -p PROFILE | jq -r '.state')" != "AVAILABLE" ]; do
  echo "Waiting..."
  sleep 30
done
echo "Instance ready!"
```

### Step 3: Get Connection Details

```bash
# Get full instance details
databricks database get-database-instance my-lakebase -p PROFILE
```

Output includes:
- `read_write_dns` - Primary endpoint (read-write)
- `read_only_dns` - Read replica endpoint
- `pg_version` - PostgreSQL version (e.g., PG_VERSION_16)

## Connecting to Lakebase

### Option 1: Databricks CLI psql (Recommended)

```bash
# Interactive session
databricks psql my-lakebase -p PROFILE

# Run single command
databricks psql my-lakebase -p PROFILE -- -c "SELECT version();"

# Connect to specific database
databricks psql my-lakebase -p PROFILE -- -d mydb -c "SELECT * FROM users;"
```

The CLI automatically handles OAuth authentication.

### Option 2: Direct psql with OAuth Token

```bash
# Generate OAuth token
TOKEN=$(databricks database generate-database-credential \
  --json '{"request_id": "cli", "instance_names": ["my-lakebase"]}' \
  -p PROFILE | jq -r '.token')

# Get host
HOST=$(databricks database get-database-instance my-lakebase -p PROFILE | jq -r '.read_write_dns')

# Connect
PGPASSWORD=$TOKEN psql \
  "host=$HOST port=5432 dbname=postgres user=you@example.com sslmode=require"
```

### Option 3: Python with psycopg2

```python
import subprocess
import json
import psycopg2

def get_lakebase_connection(instance_name: str, profile: str, database: str = "postgres"):
    """Get a connection to Lakebase using OAuth."""
    # Generate credentials
    result = subprocess.run([
        'databricks', 'database', 'generate-database-credential',
        '--json', json.dumps({
            "request_id": "python",
            "instance_names": [instance_name]
        }),
        '--profile', profile,
        '--output', 'json'
    ], capture_output=True, text=True)
    creds = json.loads(result.stdout)
    token = creds['token']

    # Get instance info
    result = subprocess.run([
        'databricks', 'database', 'get-database-instance', instance_name,
        '--profile', profile, '--output', 'json'
    ], capture_output=True, text=True)
    instance = json.loads(result.stdout)
    host = instance['read_write_dns']

    # Connect
    return psycopg2.connect(
        host=host,
        port=5432,
        database=database,
        user='you@example.com',  # Your Databricks email
        password=token,
        sslmode='require'
    )

# Usage
conn = get_lakebase_connection("my-lakebase", "my-profile", "mydb")
cur = conn.cursor()
cur.execute("SELECT * FROM users")
print(cur.fetchall())
conn.close()
```

### Option 4: SQLAlchemy

```python
from sqlalchemy import create_engine, text
import subprocess
import json

def get_lakebase_engine(instance_name: str, profile: str, database: str = "postgres"):
    """Get SQLAlchemy engine for Lakebase."""
    # Get credentials (same as above)
    result = subprocess.run([
        'databricks', 'database', 'generate-database-credential',
        '--json', json.dumps({"request_id": "sqlalchemy", "instance_names": [instance_name]}),
        '--profile', profile, '--output', 'json'
    ], capture_output=True, text=True)
    token = json.loads(result.stdout)['token']

    result = subprocess.run([
        'databricks', 'database', 'get-database-instance', instance_name,
        '--profile', profile, '--output', 'json'
    ], capture_output=True, text=True)
    host = json.loads(result.stdout)['read_write_dns']

    user = 'you@example.com'

    # URL encode special characters in token
    from urllib.parse import quote_plus
    encoded_token = quote_plus(token)

    url = f"postgresql://{user}:{encoded_token}@{host}:5432/{database}?sslmode=require"
    return create_engine(url)

# Usage
engine = get_lakebase_engine("my-lakebase", "my-profile", "mydb")
with engine.connect() as conn:
    result = conn.execute(text("SELECT * FROM users"))
    for row in result:
        print(row)
```

## Creating Databases and Tables

### Create a Database

```bash
databricks psql my-lakebase -p PROFILE -- -c "CREATE DATABASE myapp;"
```

### Create Tables

```bash
databricks psql my-lakebase -p PROFILE -- -d myapp -c "
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INT REFERENCES users(id),
    total DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);
"
```

## Managing Instance Configuration

### Scale Capacity

```bash
# Scale up to CU_4
databricks database update-database-instance my-lakebase "capacity" \
  --capacity=CU_4 \
  -p PROFILE
```

### Add Read Replicas

```bash
# Add 1 secondary node with readable secondaries enabled
databricks database update-database-instance my-lakebase "node_count,enable_readable_secondaries" \
  --node-count=2 \
  --enable-readable-secondaries \
  -p PROFILE
```

Connections to `read_only_dns` will route to the replica.

### Stop/Start Instance

```bash
# Stop instance (saves compute cost, keeps data)
databricks database update-database-instance my-lakebase "stopped" \
  --stopped \
  -p PROFILE

# Start instance
databricks database update-database-instance my-lakebase "stopped" \
  --json '{"stopped": false}' \
  -p PROFILE
```

### Change Retention Window

```bash
# Extend PITR retention to 14 days
databricks database update-database-instance my-lakebase "retention_window_in_days" \
  --retention-window-in-days=14 \
  -p PROFILE
```

## Unity Catalog Integration

### Register Lakebase Database in Unity Catalog

```bash
# Create a catalog for the Lakebase database
databricks database create-database-catalog my_catalog my-lakebase myapp \
  --create-database-if-not-exists \
  -p PROFILE
```

This allows querying Lakebase tables from Databricks SQL and notebooks:

```sql
-- In Databricks SQL
SELECT * FROM my_catalog.public.users;
```

### Create Synced Tables (Reverse ETL)

Sync data from Delta Lake to Lakebase for low-latency serving:

```bash
# Create synced table (Delta -> Lakebase)
databricks database create-synced-database-table main.default.user_profiles \
  --database-instance-name my-lakebase \
  --logical-database-name myapp \
  -p PROFILE
```

## Data API (REST)

Lakebase provides a PostgREST-compatible REST API for direct HTTP access.

### Enable Data API

```sql
-- Connect to your database
databricks psql my-lakebase -p PROFILE -- -d myapp

-- Create authenticator role
CREATE ROLE authenticator LOGIN NOINHERIT;

-- Create API role
CREATE ROLE api_user NOLOGIN;
GRANT api_user TO authenticator;
GRANT USAGE ON SCHEMA public TO api_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO api_user;
```

### Query via REST

```bash
# Get OAuth token
TOKEN=$(databricks database generate-database-credential \
  --json '{"request_id": "api", "instance_names": ["my-lakebase"]}' \
  -p PROFILE | jq -r '.token')

# Get workspace ID
WORKSPACE_ID=$(databricks current-user me -p PROFILE | jq -r '.id')

# Get instance host
HOST=$(databricks database get-database-instance my-lakebase -p PROFILE | jq -r '.read_write_dns')

# Query users table
curl -H "Authorization: Bearer $TOKEN" \
  "https://$HOST/api/2.0/workspace/$WORKSPACE_ID/rest/myapp/public/users"

# Filter results
curl -H "Authorization: Bearer $TOKEN" \
  "https://$HOST/api/2.0/workspace/$WORKSPACE_ID/rest/myapp/public/users?id=gte.2"

# Insert data
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Alice", "email": "alice@example.com"}' \
  "https://$HOST/api/2.0/workspace/$WORKSPACE_ID/rest/myapp/public/users"
```

## Deleting an Instance

```bash
# Delete instance (PERMANENT - deletes all data!)
databricks database delete-database-instance my-lakebase -p PROFILE

# Force delete if has PITR descendants
databricks database delete-database-instance my-lakebase --force -p PROFILE
```

## Troubleshooting

### "Instance state: STARTING" for too long
- Instance creation typically takes 2-5 minutes
- Check status: `databricks database get-database-instance INSTANCE -p PROFILE | jq '.state'`
- If stuck, try deleting and recreating

### Connection refused
- Ensure instance state is AVAILABLE
- Check if instance is stopped
- Verify you're using the correct endpoint (read_write_dns vs read_only_dns)

### Authentication failed
- OAuth tokens expire after 1 hour
- Regenerate token: `databricks database generate-database-credential ...`
- For psql CLI, tokens are auto-generated

### "Permission denied for table"
- Ensure your Databricks identity has a corresponding Postgres role
- Grant permissions: `GRANT SELECT ON users TO "you@example.com";`

### "Could not find psql"
- Install PostgreSQL client: `brew install postgresql@16`
- Add to PATH: `export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"`

## Pricing (AWS)

| Resource | Cost |
|----------|------|
| Compute | $0.111 per CU-hour |
| Storage | $0.35 per GB-month |
| PITR Storage | $0.20 per GB-month |

**Note**: Billing for Lakebase Autoscaling begins January 2026. Provisioned tier pricing may differ.

## Related Skills & Agents

- `/databricks-fe-vm-workspace-deployment` - Create FE-VM workspace with Lakebase support
- `/databricks-apps` - Build apps with Lakebase backend
- `/databricks-resource-deployment` - Deploy Lakebase via bundles
- `databricks-apps-developer` agent - Full-stack app development with Lakebase

## Full Example: E-commerce Backend

```bash
# 1. Create instance
databricks database create-database-instance ecommerce-db \
  --capacity=CU_2 \
  --enable-pg-native-login \
  -p my-profile

# 2. Wait for ready
while [ "$(databricks database get-database-instance ecommerce-db -p my-profile | jq -r '.state')" != "AVAILABLE" ]; do
  sleep 30
done

# 3. Create database and schema
databricks psql ecommerce-db -p my-profile -- -c "CREATE DATABASE shop;"

databricks psql ecommerce-db -p my-profile -- -d shop -c "
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    stock INT DEFAULT 0
);

CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100)
);

CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(id),
    total DECIMAL(10,2),
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INT REFERENCES orders(id),
    product_id INT REFERENCES products(id),
    quantity INT,
    price DECIMAL(10,2)
);

-- Insert sample data
INSERT INTO products (name, price, stock) VALUES
    ('Widget', 9.99, 100),
    ('Gadget', 24.99, 50),
    ('Gizmo', 14.99, 75);
"

# 4. Verify
databricks psql ecommerce-db -p my-profile -- -d shop -c "SELECT * FROM products;"
```
