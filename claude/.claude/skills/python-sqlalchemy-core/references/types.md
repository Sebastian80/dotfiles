# Column Types

## Two Type Systems

| Aspect | Generic (CamelCase) | SQL-Specific (UPPERCASE) |
|---|---|---|
| Rendering | Adapts to backend | Renders exactly as named |
| Portability | High | Database-specific |
| Example | `String` -> `VARCHAR` (PG) or `TEXT` (SQLite) | `VARCHAR` always renders `VARCHAR` |
| Use when | Building portable schemas | Targeting specific DB features |

**Rule of thumb:** Use generic types unless you need exact DDL control.

## Generic Types Reference

| SQLAlchemy Type | Python Type | SQL Type | Key Parameters |
|---|---|---|---|
| `String(n)` | `str` | `VARCHAR(n)` | `length` |
| `Text` | `str` | `TEXT` | (unbounded) |
| `Unicode(n)` | `str` | `NVARCHAR(n)` | `length` |
| `UnicodeText` | `str` | `NTEXT` | (unbounded) |
| `Integer` | `int` | `INTEGER` | |
| `BigInteger` | `int` | `BIGINT` | |
| `SmallInteger` | `int` | `SMALLINT` | |
| `Float` | `float` | `FLOAT` | `precision`, `asdecimal` |
| `Double` | `float` | `DOUBLE PRECISION` | |
| `Numeric(p, s)` | `Decimal` | `NUMERIC(p,s)` | `precision`, `scale`, `asdecimal` |
| `Boolean` | `bool` | `BOOLEAN` | `create_constraint` |
| `DateTime` | `datetime.datetime` | `DATETIME`/`TIMESTAMP` | `timezone` |
| `Date` | `datetime.date` | `DATE` | |
| `Time` | `datetime.time` | `TIME` | |
| `Interval` | `datetime.timedelta` | `INTERVAL` | `native`, `second_precision` |
| `LargeBinary` | `bytes` | `BLOB`/`BYTEA` | `length` |
| `Uuid` | `uuid.UUID` | `UUID`/`CHAR(32)` | `native_uuid`, `as_uuid` |
| `JSON` | `dict`/`list` | `JSON` | `none_as_null` |
| `Enum` | `str`/Python Enum | `ENUM`/`VARCHAR` | `native_enum`, `create_constraint`, `name` |
| `PickleType` | any | `BLOB` | `protocol` |

## Common Patterns

### Money — Use `Numeric`, Never `Float`

```python
from sqlalchemy import Numeric

Column("price", Numeric(10, 2))       # Up to 99,999,999.99
Column("tax_rate", Numeric(5, 4))     # Up to 9.9999 (e.g., 0.0825)

# Returns Decimal by default. To get float:
Column("ratio", Numeric(10, 4, asdecimal=False))

# Float is approximate — 0.1 + 0.2 != 0.3. Never use for financial data.
```

### UUIDs

```python
import uuid
from sqlalchemy import Uuid

Column("id", Uuid, primary_key=True, default=uuid.uuid4)
# PostgreSQL: native UUID type. Others: CHAR(32).

# Uuid(as_uuid=True) — returns uuid.UUID (default)
# Uuid(native_uuid=True) — use native type when available (default)
```

### JSON

```python
from sqlalchemy import JSON

Column("metadata", JSON)
Column("settings", JSON, default=dict)  # Default empty dict

# none_as_null behavior:
# JSON(none_as_null=False) — default. Python None = SQL NULL, not JSON null
# JSON(none_as_null=True) — Python None = JSON null
# To explicitly store JSON null: use JSON.NULL sentinel
```

Querying JSON:

```python
# Access nested keys
select(users).where(users.c.metadata["theme"].as_string() == "dark")

# Nested path
select(users).where(users.c.metadata["address"]["city"].as_string() == "Berlin")

# Cast JSON values for comparison
select(table).where(table.c.metadata["count"].as_integer() > 5)
select(table).where(table.c.metadata["name"].as_string() == "test")
select(table).where(table.c.metadata["active"].as_boolean() == True)
```

### Enums

```python
import enum
from sqlalchemy import Enum

class OrderStatus(enum.Enum):
    PENDING = "pending"
    SHIPPED = "shipped"
    DELIVERED = "delivered"

# Using Python Enum (creates DB ENUM type where supported)
Column("status", Enum(OrderStatus))

# Using string values
Column("priority", Enum("low", "medium", "high", name="priority_enum"))
# name= required for PostgreSQL (creates named TYPE)

# Force VARCHAR + CHECK constraint (no native ENUM)
Column("status", Enum(OrderStatus, native_enum=False))
```

### DateTime with Timezone

```python
from sqlalchemy import DateTime

Column("created_at", DateTime)                     # naive datetime
Column("created_at", DateTime(timezone=True))      # timezone-aware
```

### Arrays (PostgreSQL)

```python
from sqlalchemy import ARRAY, Integer, String

Column("scores", ARRAY(Integer))
Column("tags", ARRAY(String(50)))
Column("matrix", ARRAY(Integer, dimensions=2))  # 2D array
```

Querying:

```python
select(table).where(table.c.tags.contains(["python"]))
select(table).where(table.c.scores.any(95))
select(table).where(table.c.scores.all(100))
```

## SQL-Specific Types (UPPERCASE)

```python
from sqlalchemy import VARCHAR, CHAR, NCHAR, NVARCHAR, TEXT, CLOB
from sqlalchemy import INTEGER, BIGINT, SMALLINT
from sqlalchemy import NUMERIC, DECIMAL, FLOAT, REAL, DOUBLE, DOUBLE_PRECISION
from sqlalchemy import DATE, TIME, DATETIME, TIMESTAMP
from sqlalchemy import BOOLEAN, BINARY, VARBINARY, BLOB
from sqlalchemy import ARRAY, JSON

Column("name", VARCHAR(100))                # always renders VARCHAR
Column("created", TIMESTAMP(timezone=True)) # always renders TIMESTAMP
```

## Backend-Specific Types

```python
from sqlalchemy.dialects.postgresql import JSONB, INET, CIDR, MACADDR, TSVECTOR, TSRANGE, UUID
from sqlalchemy.dialects.mysql import TINYINT, MEDIUMINT, YEAR, SET
```

## Cross-Backend Type Variants

```python
from sqlalchemy import String
from sqlalchemy.dialects.mysql import VARCHAR as MySQL_VARCHAR

Column(
    "bio",
    String(255).with_variant(
        MySQL_VARCHAR(255, charset="utf8mb4"),
        "mysql", "mariadb",
    ),
)
# Uses MySQL-specific charset on MySQL, generic String elsewhere
```

## Custom Types with TypeDecorator

```python
from sqlalchemy.types import TypeDecorator, String
import json

class JSONString(TypeDecorator):
    """Store JSON as text in databases without native JSON support."""
    impl = String
    cache_ok = True  # REQUIRED for statement caching

    def process_bind_param(self, value, dialect):
        """Python -> database"""
        if value is not None:
            return json.dumps(value)
        return value

    def process_result_value(self, value, dialect):
        """Database -> Python"""
        if value is not None:
            return json.loads(value)
        return value

Column("config", JSONString(1000))
```

**`cache_ok = True`** — Must be set on custom types. Without it, you get warnings and degraded caching performance. Set to `True` if your type's `__init__` params are hashable and fully describe the type. Set to `False` if the type has unhashable state.

## Common Mistakes

- **`String` without length on indexed columns.** MySQL requires a length for VARCHAR in indexes. Always specify `String(N)` for indexed/unique columns.
- **Using `Float` for money.** Floating point is approximate. Use `Numeric(precision, scale)` for financial data.
- **JSON `None` confusion.** By default, Python `None` becomes SQL NULL (row has no value), not JSON `null`. Use `JSON(none_as_null=True)` if you want Python `None` to store as JSON null. Use `JSON.NULL` sentinel to explicitly store JSON null.
- **Forgetting `cache_ok` on TypeDecorator.** Omitting it produces warnings and may disable caching. Always set it.
- **Enum without `name` on PostgreSQL.** PostgreSQL creates named TYPE objects for enums. Without `name=`, auto-generated names may collide or break migrations.
- **`DateTime` without `timezone=True`.** Mixing naive and aware datetimes causes bugs. Be consistent — prefer `timezone=True`.
- **`Numeric` returns `Decimal` by default.** If you want `float`, pass `asdecimal=False`. Don't be surprised by `Decimal` in your results.
