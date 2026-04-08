# Querying (Repository Pattern)

## When to Use

You're writing repository methods that query the database using SQLAlchemy 2.0. All queries use `select()` + `session.execute()` or `session.scalars()`.

## The 2.0 Query Pattern

```python
from sqlalchemy import select
from sqlalchemy.orm import selectinload

class SqlAlchemyProductRepository:
    def __init__(self, session):
        self.session = session
        self.seen: set = set()

    def add(self, product):
        self.session.add(product)
        self.seen.add(product)

    def get(self, sku: str) -> Product:
        product = self.session.scalars(
            select(Product).where(Product.sku == sku)
        ).one_or_none()
        if product:
            self.seen.add(product)
        return product

    def get_by_id(self, id: int) -> Product | None:
        # Checks identity map first — no SQL if already loaded
        return self.session.get(Product, id)

    def list(self) -> list[Product]:
        return list(self.session.scalars(select(Product)).all())
```

## Result Retrieval Cheat Sheet

### `session.execute()` vs `session.scalars()`

```python
# execute() returns Row tuples — use for multi-column results
result = session.execute(select(Product.sku, Product.name))
for row in result:
    print(row.sku, row.name)  # Named tuple access

# scalars() returns entities directly — use for single-entity queries
products = session.scalars(select(Product)).all()
# products is list[Product], not list[Row]

# scalar() returns a single value
count = session.scalar(select(func.count()).select_from(Product))
```

### Result Methods

| Method | Returns | Use when |
|---|---|---|
| `.all()` | `list` | Want all results |
| `.one()` | Single item | Expecting exactly one (raises if 0 or 2+) |
| `.one_or_none()` | Item or `None` | Expecting zero or one (raises if 2+) |
| `.first()` | First item or `None` | Any number, want first |
| `.unique()` | Deduplicated results | **Required** after `joinedload()` on collections |

### Primary Key Lookup

```python
# session.get() checks the identity map first — no SQL if object is cached
product = session.get(Product, "SKU-001")

# Composite primary key
item = session.get(OrderLine, (order_id, line_number))
```

## Filtering

```python
# Equality
select(Product).where(Product.sku == "SKU-001")

# Comparison
select(Product).where(Product.price_amount > 1000)

# Multiple conditions (AND — all args to where())
select(Product).where(
    Product.price_amount > 500,
    Product.price_currency == "USD",
)

# OR
from sqlalchemy import or_
select(Product).where(
    or_(Product.status == "active", Product.status == "pending")
)

# IN
select(Product).where(Product.sku.in_(["SKU-001", "SKU-002"]))

# LIKE
select(Product).where(Product.name.like("%widget%"))

# IS NULL / IS NOT NULL
select(Product).where(Product.deleted_at.is_(None))
select(Product).where(Product.deleted_at.is_not(None))

# filter_by (kwargs style — still works in 2.0)
select(Product).filter_by(sku="SKU-001", status="active")
```

## Joins

```python
# Join via relationship (preferred)
select(Order).join(Order._items).where(OrderLine.sku == "SKU-001")

# Explicit join condition
select(Order).join(OrderLine, Order.order_id == OrderLine.order_id)

# Outer join
select(Order).outerjoin(Order._items)
```

## Eager Loading in Repositories

Prevent N+1 queries by loading related objects upfront:

```python
from sqlalchemy.orm import selectinload, joinedload, raiseload

# selectinload — best for collections (one-to-many)
select(Order).options(selectinload(Order._items))

# joinedload — best for scalars (many-to-one)
select(OrderLine).options(joinedload(OrderLine.product))

# Chain loading for nested relationships
select(Order).options(
    selectinload(Order._items)
    .joinedload(OrderLine.product)
)

# raiseload — prevent ALL lazy loading (catches N+1 at dev time)
select(Order).options(raiseload("*"))

# Selective raiseload — eager load what you need, raise on everything else
select(Order).options(
    selectinload(Order._items),
    raiseload("*"),
)
```

### joinedload + unique() — MANDATORY for collections

```python
# WRONG — duplicates in results
orders = session.scalars(
    select(Order).options(joinedload(Order._items))
).all()  # May contain duplicate Order objects!

# CORRECT
orders = session.scalars(
    select(Order).options(joinedload(Order._items))
).unique().all()

# BETTER — just use selectinload for collections
orders = session.scalars(
    select(Order).options(selectinload(Order._items))
).all()  # No .unique() needed
```

## Aggregations

```python
from sqlalchemy import func

# Count
count = session.scalar(select(func.count()).select_from(Product))

# Count with filter
active = session.scalar(
    select(func.count()).select_from(Product).where(Product.status == "active")
)

# Sum
total = session.scalar(
    select(func.sum(OrderLine.qty)).where(OrderLine.order_id == "ORD-001")
)

# Group by
results = session.execute(
    select(Product.price_currency, func.count())
    .group_by(Product.price_currency)
)
for currency, count in results:
    print(f"{currency}: {count}")
```

## Ordering and Limiting

```python
# Order by
select(Product).order_by(Product.name)
select(Product).order_by(Product.price_amount.desc())

# Limit and offset
select(Product).order_by(Product.name).limit(10).offset(20)
```

## Raw SQL

```python
from sqlalchemy import text

# Simple query
result = session.execute(text("SELECT * FROM products WHERE sku = :sku"), {"sku": "SKU-001"})

# In Cosmic Python, prefer this for CQRS read models:
def order_summary(order_id: str, session):
    result = session.execute(text("""
        SELECT o.order_id, o.customer_id,
               COUNT(li.id) as item_count,
               SUM(li.qty * li.unit_price) as total
        FROM orders o
        JOIN order_lines li ON li.order_id = o.order_id
        WHERE o.order_id = :order_id
        GROUP BY o.order_id, o.customer_id
    """), {"order_id": order_id})
    return dict(result.mappings().one())
```

## Common Mistakes

- **Using `session.query()`.** Legacy 1.x API. Use `select()` + `session.scalars()`.
- **Forgetting `.unique()` with `joinedload()` on collections.** Use `selectinload()` instead.
- **Raw SQL strings without `text()`.** `session.execute("SELECT ...")` no longer works. Wrap in `text()`.
- **Not tracking `.seen` in repositories.** The UoW needs `.seen` to collect domain events after commit.
- **Using `session.execute(select(Model))` and expecting entities.** `execute()` returns `Row` tuples. Use `scalars()` for entities.
