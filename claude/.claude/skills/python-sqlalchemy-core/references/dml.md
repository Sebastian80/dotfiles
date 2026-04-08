# DML Operations (INSERT, UPDATE, DELETE)

## INSERT

### Basic Insert

```python
from sqlalchemy import insert

stmt = insert(users).values(name="alice", email="[email protected]")

with engine.begin() as conn:
    result = conn.execute(stmt)
    print(result.inserted_primary_key)  # (1,) — tuple (supports composite PKs)
```

### Insert Without values() — Parameters at Execute Time

```python
stmt = insert(users)

with engine.begin() as conn:
    conn.execute(stmt, {"name": "alice", "email": "[email protected]"})
```

### Bulk Insert (executemany)

```python
with engine.begin() as conn:
    conn.execute(
        insert(users),
        [
            {"name": "alice", "email": "[email protected]"},
            {"name": "bob", "email": "[email protected]"},
            {"name": "carol", "email": "[email protected]"},
        ],
    )
```

Only the first dict determines which columns appear in the VALUES clause.

### INSERT...RETURNING

```python
stmt = insert(users).values(name="alice").returning(users.c.id, users.c.name)

with engine.begin() as conn:
    result = conn.execute(stmt)
    row = result.first()
    print(row.id, row.name)
```

### INSERT...FROM SELECT

```python
select_stmt = select(users.c.id, users.c.name + "@example.com")
stmt = insert(emails).from_select(["user_id", "email"], select_stmt)
# INSERT INTO emails (user_id, email)
# SELECT users.id, users.name || :name_1 FROM users
```

### Insert with Scalar Subquery

```python
from sqlalchemy import select, bindparam

scalar_subq = (
    select(users.c.id)
    .where(users.c.name == bindparam("username"))
    .scalar_subquery()
)

with engine.begin() as conn:
    conn.execute(
        insert(addresses).values(user_id=scalar_subq),
        [
            {"username": "alice", "email_address": "[email protected]"},
            {"username": "bob", "email_address": "[email protected]"},
        ],
    )
```

### return_defaults() — Fetch Server Defaults After Insert

```python
stmt = insert(users).values(name="alice").return_defaults()

with engine.begin() as conn:
    result = conn.execute(stmt)
    created_at = result.returned_defaults["created_at"]
```

Mutually exclusive with `returning()`.

## UPDATE

### Basic Update

```python
from sqlalchemy import update

stmt = (
    update(users)
    .where(users.c.name == "alice")
    .values(email="[email protected]")
)

with engine.begin() as conn:
    result = conn.execute(stmt)
    print(result.rowcount)  # number of matched rows
```

### Update with Expressions

```python
# Column references in SET
stmt = update(users).values(fullname="Username: " + users.c.name)
# UPDATE users SET fullname = :param_1 || users.name

# Increment a counter
stmt = update(products).where(products.c.sku == "SKU-001").values(
    stock=products.c.stock - 1
)

# Update with CASE
from sqlalchemy import case
stmt = update(orders).values(
    status=case(
        (orders.c.total >= 1000, "priority"),
        else_="standard",
    )
)
```

### Bulk Update (executemany with bindparam)

```python
from sqlalchemy import bindparam

stmt = (
    update(users)
    .where(users.c.name == bindparam("oldname"))
    .values(name=bindparam("newname"))
)

with engine.begin() as conn:
    conn.execute(
        stmt,
        [
            {"oldname": "alice", "newname": "alicia"},
            {"oldname": "bob", "newname": "robert"},
        ],
    )
```

### Update with Correlated Subquery

```python
scalar_subq = (
    select(addresses.c.email)
    .where(addresses.c.user_id == users.c.id)
    .order_by(addresses.c.id)
    .limit(1)
    .scalar_subquery()
)

stmt = update(users).values(email=scalar_subq)
# UPDATE users SET email = (SELECT addresses.email FROM addresses
#   WHERE addresses.user_id = users.id ORDER BY addresses.id LIMIT 1)
```

### UPDATE...FROM (PostgreSQL, MySQL, MSSQL)

```python
stmt = (
    update(users)
    .where(users.c.id == addresses.c.user_id)
    .where(addresses.c.email == "[email protected]")
    .values(fullname="Pat")
)
# UPDATE users SET fullname=:fullname FROM addresses
# WHERE users.id = addresses.user_id AND addresses.email = :email_1
```

### UPDATE...RETURNING

```python
stmt = (
    update(users)
    .where(users.c.name == "alice")
    .values(email="[email protected]")
    .returning(users.c.id, users.c.name)
)

with engine.begin() as conn:
    result = conn.execute(stmt)
    for row in result:
        print(row.id, row.name)
```

### Parameter-Ordered Updates (MySQL)

```python
# When SET clause order matters (e.g., SET y=20, x=y+10)
stmt = update(table).ordered_values(
    (table.c.y, 20),
    (table.c.x, table.c.y + 10),
)
```

## DELETE

### Basic Delete

```python
from sqlalchemy import delete

stmt = delete(users).where(users.c.name == "alice")

with engine.begin() as conn:
    result = conn.execute(stmt)
    print(result.rowcount)  # number of deleted rows
```

### DELETE...RETURNING

```python
stmt = (
    delete(users)
    .where(users.c.status == "inactive")
    .returning(users.c.id, users.c.name)
)

with engine.begin() as conn:
    deleted = conn.execute(stmt).all()
    for row in deleted:
        print(f"Deleted user {row.id}: {row.name}")
```

### Delete with Subquery

```python
# Delete users with no orders
from sqlalchemy import exists
stmt = delete(users).where(
    ~exists().where(orders.c.user_id == users.c.id)
)
```

## Upsert (ON CONFLICT / ON DUPLICATE KEY)

### PostgreSQL: ON CONFLICT

```python
from sqlalchemy.dialects.postgresql import insert

stmt = insert(users).values(id=1, name="alice", email="[email protected]")

# DO NOTHING on conflict
stmt_nothing = stmt.on_conflict_do_nothing(index_elements=["id"])

# DO NOTHING without specifying columns (any unique violation)
stmt_nothing = stmt.on_conflict_do_nothing()

# DO UPDATE on conflict
stmt_update = stmt.on_conflict_do_update(
    index_elements=["id"],          # which unique constraint to match
    set_=dict(
        name=stmt.excluded.name,    # use the proposed insert value
        email="[email protected]",   # use a literal value
    ),
)

# With WHERE on the update (only update matching rows)
stmt_update = stmt.on_conflict_do_update(
    index_elements=["id"],
    set_=dict(name=stmt.excluded.name),
    where=(users.c.status == "active"),
)

# Using constraint name instead of columns
stmt_update = stmt.on_conflict_do_update(
    constraint="pk_users",
    set_=dict(name=stmt.excluded.name),
)

# Using Table.primary_key
stmt_update = stmt.on_conflict_do_update(
    constraint=users.primary_key,
    set_=dict(name=stmt.excluded.name),
)

# Partial index (index_where)
stmt_update = stmt.on_conflict_do_update(
    index_elements=[users.c.email],
    index_where=users.c.email.like("%@example.com"),
    set_=dict(name=stmt.excluded.name),
)
```

**`stmt.excluded`** — namespace for the proposed insertion row values.

### SQLite: ON CONFLICT

Same API as PostgreSQL. Import from `sqlalchemy.dialects.sqlite`:

```python
from sqlalchemy.dialects.sqlite import insert

stmt = insert(users).values(id=1, name="alice")
stmt = stmt.on_conflict_do_update(
    index_elements=["id"],
    set_=dict(name=stmt.excluded.name),
)
```

### MySQL/MariaDB: ON DUPLICATE KEY UPDATE

```python
from sqlalchemy.dialects.mysql import insert
from sqlalchemy import func

stmt = insert(users).values(id=1, name="alice", email="[email protected]")

# Basic
stmt = stmt.on_duplicate_key_update(
    name=stmt.inserted.name,     # MySQL uses .inserted (not .excluded!)
    email="[email protected]",
)
# INSERT INTO users ... ON DUPLICATE KEY UPDATE name = VALUES(name), email = %s

# With expressions
stmt = stmt.on_duplicate_key_update(
    name=stmt.inserted.name,
    updated_at=func.current_timestamp(),
)

# Parameter-ordered form (list of tuples)
stmt = stmt.on_duplicate_key_update(
    [("name", stmt.inserted.name), ("updated_at", func.current_timestamp())]
)
```

**MySQL uses `stmt.inserted`**, PostgreSQL/SQLite use `stmt.excluded`.

## rowcount Behavior

```python
result = conn.execute(update(users).where(users.c.id == 1).values(name="x"))
result.rowcount  # number of MATCHED rows (not necessarily modified)
```

- Returns count of matched rows (not modified rows for UPDATE)
- Returns `-1` if unavailable
- Not reliable with RETURNING or executemany
- Backend-dependent behavior

## DML Method Summary

| Method | Available On | Purpose |
|---|---|---|
| `.values(**kw)` | Insert, Update | Set column values |
| `.where(*clauses)` | Update, Delete | Filter rows |
| `.returning(*cols)` | Insert, Update, Delete | RETURNING clause |
| `.from_select(names, select)` | Insert | INSERT...FROM SELECT |
| `.inline()` | Insert, Update | Disable implicit returning; compile defaults inline |
| `.return_defaults(*cols)` | Insert, Update | Fetch server-generated defaults |
| `.on_conflict_do_nothing()` | Insert (PG, SQLite) | Skip on conflict |
| `.on_conflict_do_update()` | Insert (PG, SQLite) | Upsert on conflict |
| `.on_duplicate_key_update()` | Insert (MySQL) | MySQL upsert |
| `.ordered_values(*tuples)` | Update | Ordered SET clause |

## Common Mistakes

- **Forgetting `conn.commit()` after DML.** With `connect()`, INSERT/UPDATE/DELETE need explicit commit. Use `engine.begin()` to auto-commit.
- **Missing WHERE on UPDATE/DELETE.** `update(users).values(active=False)` updates ALL users. Always double-check.
- **Using `stmt.excluded` on MySQL.** MySQL uses `stmt.inserted`. PostgreSQL/SQLite use `stmt.excluded`.
- **Expecting `on_conflict_do_update` to apply `Column.onupdate`.** Python-side `onupdate` defaults are NOT included in the SET clause. Manually add them to `set_=`.
- **Using `returning()` with `return_defaults()`.** Mutually exclusive. Use one or the other.
- **Trusting `rowcount` with RETURNING.** rowcount is not reliable when RETURNING is used.
- **Importing `insert` from `sqlalchemy` for upserts.** You must import from the dialect: `from sqlalchemy.dialects.postgresql import insert`. The generic `insert()` does not have `on_conflict_do_update()`.
- **Using `RETURNING` on MySQL.** MySQL doesn't support RETURNING. Use `result.lastrowid` for auto-increment IDs.
- **Bare `delete(users)` without WHERE.** Deletes ALL rows. If intentional, be explicit with a comment.
