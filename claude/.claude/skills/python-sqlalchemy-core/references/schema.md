# Schema Definition (MetaData, Table, Column)

## MetaData

Container for all Table definitions. One MetaData per schema grouping.

```python
from sqlalchemy import MetaData

metadata_obj = MetaData()

# With naming convention for constraints (recommended for Alembic migrations)
metadata_obj = MetaData(naming_convention={
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
})

# With default schema for all tables
metadata_obj = MetaData(schema="myschema")
```

## Table Definition

```python
from sqlalchemy import Table, Column, Integer, String, DateTime, ForeignKey, text

users = Table(
    "users",
    metadata_obj,
    Column("id", Integer, primary_key=True),
    Column("name", String(100), nullable=False),
    Column("email", String(255), unique=True, index=True),
    Column("status", String(20), default="active"),           # client-side default
    Column("created_at", DateTime, server_default=text("NOW()")),  # DB-side default
)
```

### Column Parameters

| Parameter | Default | Purpose |
|---|---|---|
| `primary_key` | `False` | Part of primary key |
| `nullable` | `True` (`False` if PK) | Allow NULL |
| `default` | `None` | Client-side default (scalar, callable, or SQL expression) |
| `server_default` | `None` | Database-side DEFAULT clause (string, `text()`, or `FetchedValue`) |
| `onupdate` | `None` | Client-side value on UPDATE |
| `server_onupdate` | `None` | DB-side value on UPDATE (informational only) |
| `unique` | `False` | Generate UNIQUE constraint |
| `index` | `False` | Generate index on this column |
| `autoincrement` | `"auto"` | Auto-increment behavior (`True`/`False`/`"auto"`/`"ignore_fk"`) |
| `key` | `None` | Alternate Python identifier for column access |
| `comment` | `None` | SQL COMMENT on column |
| `info` | `{}` | User-defined metadata dict |

### Client-Side vs Server-Side Defaults

```python
import datetime

# Client-side: Python generates the value before INSERT
Column("created_at", DateTime, default=datetime.datetime.utcnow)  # callable — NO parens
Column("status", String, default="pending")                        # scalar

# Server-side: Database generates the value (appears in DDL)
Column("created_at", DateTime, server_default=text("NOW()"))
Column("uuid", String(36), server_default=text("gen_random_uuid()"))

# Server-side with simple string (converted to DEFAULT 'value')
Column("is_active", Boolean, server_default="true")

# PostgreSQL array default
from sqlalchemy import ARRAY, Text
from sqlalchemy.dialects.postgresql import array
Column("tags", ARRAY(Text), server_default=array(["default"]))
```

Use `server_default` when you want the default to work even for raw SQL inserts outside SQLAlchemy.

## Foreign Keys

```python
from sqlalchemy import ForeignKey, ForeignKeyConstraint

# Inline (single column)
Column("user_id", Integer, ForeignKey("users.id"))

# With cascade
Column("user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"))
# ON DELETE options: CASCADE, SET NULL, SET DEFAULT, RESTRICT, NO ACTION

# With schema prefix
Column("account_id", Integer, ForeignKey("banking.accounts.id"))

# Composite foreign key (table-level constraint)
orders = Table(
    "orders",
    metadata_obj,
    Column("id", Integer, primary_key=True),
    Column("customer_org", String(50)),
    Column("customer_id", Integer),
    ForeignKeyConstraint(
        ["customer_org", "customer_id"],
        ["customers.org", "customers.id"],
    ),
)
```

## Constraints

```python
from sqlalchemy import UniqueConstraint, CheckConstraint, PrimaryKeyConstraint, Index

users = Table(
    "users",
    metadata_obj,
    Column("id", Integer),
    Column("name", String(100)),
    Column("email", String(255)),
    Column("org_id", Integer),

    # Composite primary key
    PrimaryKeyConstraint("id", "org_id"),

    # Multi-column unique
    UniqueConstraint("name", "org_id", name="uq_user_org"),

    # Check constraint
    CheckConstraint("length(name) > 0", name="ck_name_nonempty"),
)
```

## Indexes

```python
from sqlalchemy import Index

# Inline on column
Column("email", String(255), index=True)

# Explicit index (more control)
Index("ix_users_name", users.c.name)

# Composite index
Index("ix_users_org_name", users.c.org_id, users.c.name)

# Unique index
Index("ix_users_email", users.c.email, unique=True)

# Partial index (PostgreSQL)
Index("ix_active_users", users.c.name, postgresql_where=users.c.status == "active")
```

## Accessing Table and Column Objects

```python
# Column access
users.c.name                  # attribute access
users.c["name"]               # string key access
users.c["name", "email"]      # multiple columns (2.0+)

# Iteration
for col in users.c:
    print(col.name, col.type)

# Primary key columns
for pk_col in users.primary_key:
    print(pk_col)

# Foreign keys
for fk in users.foreign_keys:
    print(fk)

# Column properties
users.c.name.name              # "name"
users.c.name.type              # String(100)
users.c.name.nullable          # True/False
users.c.name.primary_key       # True/False
users.c.name.table             # users Table object

# Tables sorted by FK dependency (for create/drop order)
for table in metadata_obj.sorted_tables:
    print(table.name)

# Access table by name from metadata
users = metadata_obj.tables["users"]
users = metadata_obj.tables["myschema.users"]  # schema-qualified
```

## Creating and Dropping Tables

```python
engine = create_engine("sqlite:///:memory:")

# Create all tables (checks existence by default)
metadata_obj.create_all(engine)

# Drop all tables
metadata_obj.drop_all(engine)

# Create specific tables
metadata_obj.create_all(engine, tables=[users, orders])

# Individual table (must use checkfirst to avoid errors)
users.create(engine, checkfirst=True)
users.drop(engine, checkfirst=True)
```

## Table Reflection (Loading Schema from Database)

```python
# Reflect a single table
messages = Table("messages", metadata_obj, autoload_with=engine)
print([c.name for c in messages.columns])

# Reflect all tables in database
metadata_obj = MetaData()
metadata_obj.reflect(bind=engine)
users = metadata_obj.tables["users"]

# Reflect with specific schema
metadata_obj.reflect(bind=engine, schema="myschema")

# Override reflected columns (custom types, constraints)
mytable = Table(
    "mytable",
    metadata_obj,
    Column("id", Integer, primary_key=True),    # override
    Column("data", Unicode(50)),                  # override
    autoload_with=engine,                         # reflect the rest
)

# Useful pattern: clear all rows in correct FK order
metadata_obj = MetaData()
metadata_obj.reflect(bind=engine)
with engine.begin() as conn:
    for table in reversed(metadata_obj.sorted_tables):
        conn.execute(table.delete())
```

### Database Introspection with inspect()

```python
from sqlalchemy import inspect

insp = inspect(engine)

insp.get_table_names()                           # all table names
insp.get_table_names(schema="myschema")          # in specific schema
insp.get_columns("users")                        # column definitions with types
insp.get_indexes("users")                        # indexes
insp.get_foreign_keys("users")                   # foreign keys
insp.get_pk_constraint("users")                  # primary key
insp.get_unique_constraints("users")             # unique constraints
insp.has_table("users")                          # existence check
insp.get_schema_names()                          # available schemas
```

## Multi-Schema Support

```python
# Schema on individual table
financial = Table(
    "accounts",
    metadata_obj,
    Column("id", Integer, primary_key=True),
    schema="banking",
)
# Renders: SELECT banking.accounts.id FROM banking.accounts

# Schema on MetaData (default for all tables)
metadata_obj = MetaData(schema="banking")

# Override to use default schema (no prefix)
from sqlalchemy import BLANK_SCHEMA
public_table = Table("public_data", metadata_obj, ..., schema=BLANK_SCHEMA)

# Runtime schema switching (multi-tenancy)
conn = engine.connect().execution_options(
    schema_translate_map={None: "tenant_42"}
)
# Table objects without explicit schema render as tenant_42.tablename

# Multiple schema mappings
conn = engine.connect().execution_options(
    schema_translate_map={
        None: "tenant_schema",
        "shared": "shared_schema",
        "public": None,  # removes schema prefix
    }
)
```

## Backend-Specific Options

```python
# MySQL engine type
addresses = Table(
    "addresses",
    metadata_obj,
    Column("id", Integer, primary_key=True),
    Column("email", String(100)),
    mysql_engine="InnoDB",
)
```

## Common Mistakes

- **`MetaData(bind=engine)`.** Removed in 2.0. Pass engine to `create_all(engine)`.
- **Not setting `naming_convention` on MetaData.** Without it, constraints get auto-generated names that vary by backend, breaking Alembic migrations.
- **Using `default=datetime.datetime.utcnow()` (with parens).** Captures a single timestamp at definition time. Use `default=datetime.datetime.utcnow` (callable, no parens).
- **Confusing `default` and `server_default`.** `default` is Python-side (value included in INSERT). `server_default` is DB-side DEFAULT clause (in DDL).
- **Not using `checkfirst=True` on individual create/drop.** Without it, errors if table already exists or doesn't exist. `create_all()`/`drop_all()` use checkfirst by default.
- **`String` without length on indexed columns.** Some databases (MySQL) require a length for VARCHAR in indexes. Always specify `String(N)` for indexed/unique columns.
- **Missing `name=` on constraints.** Unnamed constraints get auto-generated names that differ across dialects, making migrations harder.
- **Reflecting without expecting FK cascading.** If table A has FK to table B, reflecting A also reflects B. Automatic but can be surprising.
