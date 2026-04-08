# Transactions

## The 2.0 Transaction Model

SQLAlchemy 2.0 uses **autobegin** — a transaction starts implicitly on the first `execute()` call. There is NO implicit autocommit. You must always commit explicitly or use `engine.begin()`.

## Three Transaction Patterns

### Pattern 1: "Commit As You Go" (most flexible)

```python
with engine.connect() as conn:
    conn.execute(some_table.insert(), {"x": 7, "y": "data"})
    conn.execute(other_table.insert(), {"q": 8, "p": "more"})
    conn.commit()  # REQUIRED — nothing persists without this
```

Multiple transactions in one connection:

```python
with engine.connect() as conn:
    conn.execute(text("INSERT INTO t1 ..."))
    conn.commit()  # commits first transaction

    conn.execute(text("INSERT INTO t2 ..."))
    conn.rollback()  # rolls back second transaction

    conn.execute(text("INSERT INTO t3 ..."))
    conn.commit()  # commits third transaction
```

### Pattern 2: "Begin Once" (explicit block)

```python
with engine.connect() as conn:
    with conn.begin():
        conn.execute(some_table.insert(), {"x": 7})
        conn.execute(other_table.insert(), {"q": 8})
    # auto-committed on block exit; auto-rollback on exception
```

### Pattern 3: "Connect and Begin" (shorthand)

```python
with engine.begin() as conn:
    conn.execute(some_table.insert(), {"x": 7})
    conn.execute(other_table.insert(), {"q": 8})
# auto-committed on exit; auto-rollback on exception
```

### Mixing Patterns

```python
with engine.connect() as conn:
    with conn.begin():
        conn.execute(...)  # in explicit block

    # new autobegin transaction
    conn.execute(...)
    conn.commit()

    with conn.begin():
        conn.execute(...)  # another explicit block
```

## Savepoints (Nested Transactions)

```python
with engine.begin() as conn:
    conn.execute(text("INSERT INTO t VALUES (1)"))

    with conn.begin_nested():  # SAVEPOINT
        conn.execute(text("INSERT INTO t VALUES (2)"))
        # can rollback just this savepoint independently

    conn.execute(text("INSERT INTO t VALUES (3)"))
# outer transaction commits rows 1 and 3 (and 2 if savepoint wasn't rolled back)
```

## Isolation Levels

### Per-Connection

```python
with engine.connect().execution_options(
    isolation_level="REPEATABLE READ"
) as conn:
    with conn.begin():
        conn.execute(text("SELECT ..."))
```

Supported values: `"READ UNCOMMITTED"`, `"READ COMMITTED"`, `"REPEATABLE READ"`, `"SERIALIZABLE"`, `"AUTOCOMMIT"`

### Per-Engine

```python
engine = create_engine(url, isolation_level="REPEATABLE READ")
```

### AUTOCOMMIT Mode

Every statement commits immediately. No transaction grouping.

```python
# Preferred: separate connection checkout
with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as conn:
    conn.execute(text("ALTER TABLE ..."))  # DDL commits immediately

# For MySQL — skip unnecessary ROLLBACK on return to pool
autocommit_engine = create_engine(url, isolation_level="AUTOCOMMIT", skip_autocommit_rollback=True)
```

## Common Mistakes

- **Forgetting `conn.commit()` with `connect()`.** The transaction rolls back on connection close — your INSERT/UPDATE silently disappears.
- **Calling `begin()` after autobegin.** If you already called `execute()`, autobegin has started a transaction. `conn.begin()` raises `InvalidRequestError`. Call `begin()` before any statements, or after `commit()`/`rollback()`.
- **Switching isolation levels mid-connection.** Use separate connection checkouts instead of changing isolation on the same connection.
- **Assuming AUTOCOMMIT still groups with `begin()`.** Under AUTOCOMMIT, calling `conn.begin()` raises if autobegin already occurred.

## 1.x to 2.0 Migration

| 1.x pattern | 2.0 equivalent |
|---|---|
| Implicit autocommit (DML outside transaction) | Explicit `conn.commit()` required |
| `conn.execution_options(autocommit=True)` | `conn.execution_options(isolation_level="AUTOCOMMIT")` |
| Connection not in transaction state | Always in autobegin state after first execute |
