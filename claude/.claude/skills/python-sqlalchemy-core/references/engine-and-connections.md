# Engine and Connections

## Creating an Engine

```python
from sqlalchemy import create_engine

# PostgreSQL
engine = create_engine("postgresql+psycopg2://user:pass@localhost:5432/mydb")

# SQLite (file)
engine = create_engine("sqlite:///path/to/database.db")

# SQLite (in-memory)
engine = create_engine("sqlite:///:memory:")

# MySQL
engine = create_engine("mysql+pymysql://user:pass@localhost/mydb")

# Oracle
engine = create_engine("oracle+oracledb://user:pass@host:1521/?service_name=freepdb1")

# MS SQL Server
engine = create_engine("mssql+pyodbc://user:pass@mydsn")
```

### URL Format

```
dialect+driver://username:password@host:port/database?key=value
```

| Component | Examples |
|---|---|
| dialect | `postgresql`, `mysql`, `sqlite`, `mssql`, `oracle` |
| driver | `psycopg2`, `asyncpg`, `pymysql`, `aiosqlite`, `oracledb` |
| host | `localhost`, `db.example.com` |
| port | `5432` (postgres), `3306` (mysql) |

### Special Characters in Passwords

```python
# Option 1: URL-encode special chars
import urllib.parse
urllib.parse.quote_plus("kx@jj5/g")  # Returns: 'kx%40jj5%2Fg'
engine = create_engine("postgresql+pg8000://user:kx%40jj5%2Fg@host/db")

# Option 2: URL.create() — no escaping needed (preferred)
from sqlalchemy import URL
url = URL.create(
    "postgresql+psycopg2",
    username="user",
    password="kx@jj5/g",  # plain text
    host="host",
    database="db",
)
engine = create_engine(url)
```

### SQLite Path Gotchas

```python
engine = create_engine("sqlite:///relative/path.db")       # Relative: 3 slashes
engine = create_engine("sqlite:////absolute/path.db")       # Absolute Unix: 4 slashes
engine = create_engine(r"sqlite:///C:\path\to\db.db")       # Windows: raw string
engine = create_engine("sqlite://")                          # In-memory
```

### Key Engine Parameters

```python
engine = create_engine(
    url,
    echo=False,             # True = log all SQL (dev only); "debug" = log result rows
    pool_size=5,            # Max persistent connections (default: 5)
    max_overflow=10,        # Extra connections when pool full (default: 10)
    pool_timeout=30,        # Seconds to wait for connection (default: 30)
    pool_recycle=-1,        # Recycle after N seconds (default: -1 = never)
    pool_pre_ping=False,    # Test connections before use
    isolation_level=None,   # Transaction isolation ("READ COMMITTED", "SERIALIZABLE", etc.)
    connect_args={},        # Dict passed directly to DBAPI connect()
    query_cache_size=500,   # SQL compilation cache size
    hide_parameters=False,  # Hide SQL params from logging (for secrets)
)
```

**Production checklist:**
- `pool_pre_ping=True` — detects stale connections (firewalls, load balancers drop idle)
- `pool_recycle=3600` — recycle every hour (MySQL closes idle after `wait_timeout`, default 8h)
- `echo=False` — never in production

### Connection Pooling

| Pool type | When to use |
|---|---|
| `QueuePool` (default) | Most applications |
| `NullPool` | Short scripts, serverless, AWS Lambda (no pooling) |
| `StaticPool` | In-memory SQLite (one connection shared) |
| `SingletonThreadPool` | SQLite default (one connection per thread) |
| `AsyncAdaptedQueuePool` | Async drivers (asyncpg, aiosqlite) |

```python
from sqlalchemy.pool import NullPool, StaticPool

# No pooling (AWS Lambda, short scripts)
engine = create_engine(url, poolclass=NullPool)

# In-memory SQLite for testing (share one connection)
engine = create_engine("sqlite://", poolclass=StaticPool)
```

### Passing DBAPI-Level Options

```python
# Via URL query string (simple string/numeric values)
engine = create_engine("mysql+pymysql://user:pass@host/db?charset=utf8mb4")

# Via connect_args (complex objects, non-string types)
engine = create_engine(
    "postgresql+psycopg2://user:pass@host/db",
    connect_args={"connection_factory": MyFactory, "timeout": 30},
)

# Via event hooks (dynamic auth, post-connect commands)
from sqlalchemy import event

@event.listens_for(engine, "do_connect")
def provide_token(dialect, conn_rec, cargs, cparams):
    cparams["token"] = get_authentication_token()

@event.listens_for(engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.close()
```

### Engine Lifecycle

- **Lazy**: No DBAPI connections until first `connect()` or `begin()`
- **One per database**: Keep a single Engine per database URL; it manages the pool
- **Disposal**: Call `engine.dispose()` when shutting down or replacing engines

### engine_from_config()

```python
# Useful with config files (INI, .env)
config = {
    "sqlalchemy.url": "postgresql://user:pass@host/db",
    "sqlalchemy.echo": "true",
    "sqlalchemy.pool_size": "20",
}
from sqlalchemy import engine_from_config
engine = engine_from_config(config, prefix="sqlalchemy.")
```

## Using Connections

```python
# ALWAYS use context managers
with engine.connect() as conn:
    result = conn.execute(text("SELECT 1"))
    conn.commit()
# Connection returned to pool on exit

# begin() auto-commits on success, rolls back on exception
with engine.begin() as conn:
    conn.execute(text("INSERT INTO users (name) VALUES (:name)"), {"name": "Alice"})
# Auto-committed here
```

### `connect()` vs `begin()`

| Method | Commit behavior | On exception |
|---|---|---|
| `engine.connect()` | Manual: call `conn.commit()` | Rollback + close |
| `engine.begin()` | Auto-commit on exit | Rollback + close |

Use `connect()` when you need fine-grained transaction control. Use `begin()` for simple atomic operations.

### Executing Statements

```python
from sqlalchemy import text

with engine.connect() as conn:
    # text() for raw SQL — REQUIRED in 2.0
    result = conn.execute(text("SELECT * FROM users WHERE id = :id"), {"id": 42})

    # Iterate rows
    for row in result:
        print(row.name, row.email)  # Named tuple access

    # Fetch methods
    row = result.first()          # First row or None
    row = result.one()            # Exactly one (raises if 0 or 2+)
    row = result.one_or_none()    # Zero or one (raises if 2+)
    rows = result.all()           # List of all rows
    rows = result.fetchmany(10)   # Next N rows

    # Dict-like access
    for row in result.mappings():
        print(row["name"], row["email"])

    # Single-column results
    names = conn.execute(text("SELECT name FROM users")).scalars().all()

    # Scalar (single value)
    count = conn.execute(text("SELECT count(*) FROM users")).scalar()
```

### Row Object Access

```python
row = result.first()
row.name               # attribute access
row[0]                 # positional access
row._mapping           # dict-like access
row._asdict()          # convert to dict
row._tuple()           # convert to tuple
```

### Large Result Sets (Server-Side Cursors)

```python
# Fixed-size partitions
with engine.connect() as conn:
    with conn.execution_options(yield_per=100).execute(
        text("SELECT * FROM big_table")
    ) as result:
        for partition in result.partitions():
            for row in partition:  # up to 100 rows per partition
                process(row)

# Streaming with dynamic buffer
with engine.connect() as conn:
    with conn.execution_options(stream_results=True, max_row_buffer=100).execute(
        text("SELECT * FROM big_table")
    ) as result:
        for row in result:
            process(row)
```

### Execution Options

```python
# Set per-connection
conn = conn.execution_options(isolation_level="SERIALIZABLE")

# Schema translation (multi-tenancy)
conn = engine.connect().execution_options(
    schema_translate_map={None: "tenant_schema"}
)
# Table objects without explicit schema now render as tenant_schema.tablename

# Logging tokens for request tracing
with engine.connect().execution_options(logging_token="req-abc123") as conn:
    conn.execute(text("SELECT 1"))  # logs: [req-abc123] SELECT 1
```

## Common Mistakes

- **Bare SQL strings.** `conn.execute("SELECT 1")` fails in 2.0. Always use `text()`.
- **Forgetting `conn.commit()`.** With `connect()`, changes are not persisted without explicit commit.
- **Not using context managers.** `conn = engine.connect()` without `with` leaks connections.
- **Using `engine.execute()`.** Removed in 2.0. Always go through a connection.
- **Assuming `engine.begin()` needs `commit()`.** It auto-commits on context exit.
- **Creating multiple engines per database.** Keep one Engine; it manages the pool.
- **Mixing echo and logging.** Use `echo=True` OR `logging.getLogger("sqlalchemy.engine")`, not both.
- **`schema_translate_map` with `text()`.** Translation only works on Table-based constructs, not raw SQL strings.
