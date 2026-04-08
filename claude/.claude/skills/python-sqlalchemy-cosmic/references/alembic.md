# Alembic with Imperative Mapping

## The Problem

Alembic's `--autogenerate` expects to find your models via a declarative `Base.metadata`. With Cosmic Python's imperative mapping, there is no `Base` — you have a `registry` with `metadata`. The setup requires pointing Alembic at the right metadata and ensuring mappers are configured before autogenerate runs.

## Initial Setup

```bash
# Install
uv add alembic

# Initialize (creates alembic/ directory and alembic.ini)
alembic init alembic
```

This creates:
```
alembic/
├── env.py              # Configure here
├── script.py.mako      # Migration template
└── versions/           # Generated migrations
alembic.ini             # Connection URL and settings
```

## Configuring env.py for Imperative Mapping

The key change: import your `metadata` from `adapters/orm.py` and call `start_mappers()` before autogenerate runs.

```python
# alembic/env.py
from logging.config import fileConfig
from sqlalchemy import engine_from_config, pool
from alembic import context

# CRITICAL: Import YOUR metadata and start mappers
from adapters.orm import metadata, start_mappers

# Start mappers so all Table definitions are registered with metadata
start_mappers()

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Point Alembic at your metadata
target_metadata = metadata


def run_migrations_offline():
    """Generate SQL without connecting to the database."""
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online():
    """Run migrations against a live database."""
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

## alembic.ini Configuration

```ini
[alembic]
script_location = alembic
sqlalchemy.url = postgresql://user:pass@localhost/mydb

# For env var substitution (recommended for secrets):
# sqlalchemy.url = postgresql://%(DB_USER)s:%(DB_PASS)s@%(DB_HOST)s/%(DB_NAME)s
```

### Using Environment Variables for the URL

```python
# In env.py, override the URL from environment
import os

def run_migrations_online():
    url = os.environ.get("DATABASE_URL", config.get_main_option("sqlalchemy.url"))
    connectable = create_engine(url, poolclass=pool.NullPool)
    # ... rest of function
```

## Generating Migrations

```bash
# Autogenerate a migration from model changes
alembic revision --autogenerate -m "add orders table"

# Create an empty migration (for manual edits)
alembic revision -m "add custom index"

# Run migrations
alembic upgrade head

# Rollback one step
alembic downgrade -1

# Show current version
alembic current

# Show migration history
alembic history
```

## What Autogenerate Detects

| Change | Detected? | Notes |
|---|---|---|
| New table | Yes | |
| Dropped table | Yes | |
| New column | Yes | |
| Dropped column | Yes | |
| Column type change | Partial | May miss some type changes |
| Column nullable change | Yes | |
| New index | Yes | |
| Dropped index | Yes | |
| New constraint | Yes | With naming convention |
| Renamed column/table | No | Generates drop + add instead |
| Data migration | No | Write manually |

## Naming Conventions (Critical)

Without a naming convention, constraints get auto-generated names that differ across databases, causing migration issues. Always set this on your MetaData:

```python
# adapters/orm.py
from sqlalchemy import MetaData

metadata = MetaData(naming_convention={
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
})

# Then use this metadata for all tables:
mapper_registry = registry(metadata=metadata)
# OR
mapper_registry = registry()
metadata = mapper_registry.metadata  # Then add naming convention separately
```

Wait — the `registry()` creates its own metadata. To use a naming convention with `registry`:

```python
from sqlalchemy import MetaData
from sqlalchemy.orm import registry

convention = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

metadata = MetaData(naming_convention=convention)
mapper_registry = registry(metadata=metadata)

# Now all tables use this metadata with naming conventions
products = Table("products", metadata, ...)
```

## Common Migration Patterns

### Adding a Column with Default

```python
# In the generated migration
def upgrade():
    op.add_column("orders", sa.Column("status", sa.String(50), server_default="pending"))

def downgrade():
    op.drop_column("orders", "status")
```

### Data Migration

```python
from alembic import op
import sqlalchemy as sa

def upgrade():
    # Schema change
    op.add_column("users", sa.Column("full_name", sa.String(255)))

    # Data migration — use raw SQL or the connection
    conn = op.get_bind()
    conn.execute(
        sa.text("UPDATE users SET full_name = first_name || ' ' || last_name")
    )

    # Then drop old columns
    op.drop_column("users", "first_name")
    op.drop_column("users", "last_name")
```

### Adding a Non-Nullable Column to Existing Table

```python
def upgrade():
    # 1. Add as nullable
    op.add_column("orders", sa.Column("customer_id", sa.String(255), nullable=True))

    # 2. Backfill data
    conn = op.get_bind()
    conn.execute(sa.text("UPDATE orders SET customer_id = 'UNKNOWN' WHERE customer_id IS NULL"))

    # 3. Make non-nullable
    op.alter_column("orders", "customer_id", nullable=False)
```

## Import Path Gotcha

If your project uses a `src/` layout, Alembic needs to find your modules. Add to `env.py`:

```python
import sys
from pathlib import Path

# Add src/ to Python path so imports work
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from adapters.orm import metadata, start_mappers
```

## Common Mistakes

- **Not calling `start_mappers()` in `env.py`.** Without it, no tables are registered and autogenerate produces empty migrations.
- **Missing naming convention.** Constraints get random names, making `downgrade()` impossible across databases.
- **Using `registry.metadata` without a naming convention.** The registry creates a plain MetaData. Pass `MetaData(naming_convention=...)` to `registry(metadata=...)`.
- **Forgetting `sys.path` for `src/` layout.** Alembic can't import your modules if they're not on the path.
- **Running autogenerate against production.** Always generate against a dev database that matches your model, not production data.
- **Not reviewing autogenerated migrations.** Autogenerate is a starting point, not a finished product. Always review, especially for renames (which show as drop+add).
