# Migration from SQLAlchemy 1.x to 2.0

## When to Use

You're working with code that uses SQLAlchemy 1.x patterns, or you're seeing deprecation warnings. This reference maps every deprecated pattern to its 2.0 replacement.

## Detection

Set the environment variable to surface all deprecated usage:

```bash
SQLALCHEMY_WARN_20=1 python your_app.py
```

This triggers `RemovedIn20Warning` for every 1.x pattern. Fix them all before upgrading to 2.0.

## Pattern Replacements

### Querying

```python
# 1.x (DEPRECATED)
session.query(Product).filter_by(sku="SKU-001").first()
session.query(Product).filter(Product.sku == "SKU-001").all()
session.query(Product).get("SKU-001")
session.query(func.count(Product.id)).scalar()

# 2.0 (USE THIS)
session.scalars(select(Product).filter_by(sku="SKU-001")).first()
session.scalars(select(Product).where(Product.sku == "SKU-001")).all()
session.get(Product, "SKU-001")
session.scalar(select(func.count()).select_from(Product))
```

### Mapper

```python
# 1.x (REMOVED)
from sqlalchemy.orm import mapper
mapper(Product, products_table)

# 2.0 (USE THIS)
from sqlalchemy.orm import registry
mapper_registry = registry()
mapper_registry.map_imperatively(Product, products_table)
```

### Engine and Connections

```python
# 1.x (REMOVED) — "connectionless execution"
engine.execute(text("SELECT 1"))
metadata.create_all(bind=engine)  # bind parameter on MetaData

# 2.0 (USE THIS)
with engine.connect() as conn:
    conn.execute(text("SELECT 1"))
    conn.commit()

metadata.create_all(engine)  # Pass engine directly
```

### Session

```python
# 1.x (REMOVED)
Session(autocommit=True)
session.begin(subtransactions=True)

# 2.0 (USE THIS)
Session()  # autobegin is the default — commit() explicitly
session.begin_nested()  # For SAVEPOINTs
```

### Relationships

```python
# 1.x (DEPRECATED)
relationship(OrderLine, backref="order")

# 2.0 (USE THIS) — explicit both sides
# On Order:
relationship(OrderLine, back_populates="order")
# On OrderLine:
relationship(Order, back_populates="_items")
```

### Declarative Base

```python
# 1.x (DEPRECATED import path)
from sqlalchemy.ext.declarative import declarative_base
Base = declarative_base()

# 2.0 (USE THIS — if you use declarative at all)
from sqlalchemy.orm import DeclarativeBase
class Base(DeclarativeBase):
    pass

# Or for Cosmic Python (PREFERRED — no declarative base needed)
from sqlalchemy.orm import registry
mapper_registry = registry()
```

### select() Syntax

```python
# 1.x (DEPRECATED)
select([Product.sku, Product.name])  # List argument
select([Product])  # List argument

# 2.0 (USE THIS)
select(Product.sku, Product.name)  # Positional args
select(Product)  # Positional arg
```

### Raw SQL

```python
# 1.x (REMOVED)
session.execute("SELECT * FROM products WHERE sku = :sku", {"sku": "SKU-001"})

# 2.0 (USE THIS)
from sqlalchemy import text
session.execute(text("SELECT * FROM products WHERE sku = :sku"), {"sku": "SKU-001"})
```

### Result Handling

```python
# 1.x — query() returns model instances directly
products = session.query(Product).all()  # list[Product]

# 2.0 — execute() returns Row tuples, scalars() returns entities
rows = session.execute(select(Product)).all()  # list[Row] — NOT list[Product]!
products = session.scalars(select(Product)).all()  # list[Product] — correct
```

### Lazy Loading

```python
# 1.x (DEPRECATED)
relationship(OrderLine, lazy="dynamic")  # Returns Query object

# 2.0 (USE THIS)
relationship(OrderLine, lazy="write_only")  # New 2.0 feature, bulk write only
# Or for read access, use selectinload() in queries
```

## Behavioral Changes (No Code Change Needed, But Be Aware)

1. **Transactions autobegin.** First database operation starts a transaction. `commit()`/`rollback()` without an active transaction is a no-op.

2. **`cascade_backrefs` is always `False`.** In 1.x it defaulted to `True` — adding a child to a parent would auto-add the child to the session via the backref. In 2.0, you must explicitly `session.add()`.

3. **`joinedload()` on collections requires `.unique()`.** The JOIN produces duplicate parent rows. Call `.unique()` on the result, or use `selectinload()`.

4. **Result rows are named tuples.** Access by attribute (`row.sku`) or index (`row[0]`), not by column name as a dict key. Use `row._mapping` for dict-like access.

## Migration Strategy

1. **Start on SQLAlchemy 1.4** with `SQLALCHEMY_WARN_20=1` to find all deprecated usage
2. **Fix warnings one pattern at a time** — each fix works in both 1.4 and 2.0
3. **Add `future=True`** to `create_engine()` and `sessionmaker()` to opt into 2.0 behavior on 1.4
4. **Upgrade to 2.0** when all warnings are resolved and tests pass

## Common Mistakes

- **Mixing 1.x and 2.0 patterns.** Pick one and be consistent. Using `session.query()` in half the codebase and `select()` in the other half is confusing.
- **Forgetting `text()` for raw SQL.** Bare strings silently fail or raise in 2.0.
- **Using `execute()` when you need `scalars()`.** `execute()` returns `Row` tuples. Use `scalars()` for ORM entities.
- **Not testing after migration.** Behavioral changes (cascade_backrefs, autobegin) can cause subtle bugs. Run your full test suite.
