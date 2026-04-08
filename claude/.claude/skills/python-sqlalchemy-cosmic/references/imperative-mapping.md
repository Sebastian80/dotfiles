# Imperative Mapping

## When to Use

You're mapping domain classes to database tables while keeping the domain model free of SQLAlchemy imports. This is the foundation of the Cosmic Python ORM layer.

## The Pattern

All SQLAlchemy configuration lives in `adapters/orm.py`. Domain classes in `domain/model.py` are pure Python.

```python
# adapters/orm.py
from sqlalchemy import Table, Column, Integer, String, ForeignKey, MetaData
from sqlalchemy.orm import registry, relationship

mapper_registry = registry()
metadata = mapper_registry.metadata

# --- Table definitions ---

products = Table(
    "products", metadata,
    Column("sku", String(255), primary_key=True),
    Column("name", String(255)),
    Column("price_amount", Integer),
    Column("price_currency", String(3)),
    Column("version_number", Integer, nullable=False, server_default="0"),
)

order_lines = Table(
    "order_lines", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("sku", String(255)),
    Column("qty", Integer),
    Column("order_id", String(255), ForeignKey("orders.order_id")),
)

orders = Table(
    "orders", metadata,
    Column("order_id", String(255), primary_key=True),
    Column("customer_id", String(255)),
    Column("status", String(50)),
)


# --- Mapper configuration ---

def start_mappers():
    """Call once at app startup. Maps domain classes to tables."""
    lines_mapper = mapper_registry.map_imperatively(
        OrderLine, order_lines
    )
    mapper_registry.map_imperatively(
        Order, orders,
        properties={
            "_items": relationship(
                lines_mapper,
                collection_class=list,
            ),
        },
    )
    mapper_registry.map_imperatively(Product, products)
```

## Implementation Rules

1. **One `start_mappers()` function, called exactly once.** Call it in `bootstrap.py` at application startup. Calling it twice raises `sqlalchemy.exc.ArgumentError`.

2. **Use `registry.map_imperatively()`**, not the removed `mapper()`. The registry provides the metadata and coordinates all mappings.

3. **Relationships go in the `properties` dict.** The keys become attribute names on the domain class. If your domain class uses `_items` internally, map to `"_items"`.

4. **You can reference either the class or the mapper as the relationship target.** Both work:
   ```python
   # By mapper (returned from map_imperatively)
   lines_mapper = mapper_registry.map_imperatively(OrderLine, order_lines)
   properties={"lines": relationship(lines_mapper)}

   # By class (if already mapped)
   properties={"lines": relationship(OrderLine)}
   ```

5. **All relationships must be defined at mapping time.** You cannot add relationships after `map_imperatively()`. Plan your mapping order: map child entities first, then parents that reference them.

6. **Map value objects as composite columns or embedded fields.** For simple value objects like `Money(amount, currency)`, map the individual fields to columns:
   ```python
   # Table has: price_amount INTEGER, price_currency VARCHAR(3)
   # Domain class has: price: Money
   # Handle in the mapper with column_property or in the domain __init__
   ```

7. **For composite primary keys:**
   ```python
   some_table = Table(
       "some_table", metadata,
       Column("key1", String, primary_key=True),
       Column("key2", String, primary_key=True),
   )
   ```

## Mapping Order

Map entities in dependency order — children before parents:

```python
def start_mappers():
    # 1. Map leaf entities (no relationships to configure)
    mapper_registry.map_imperatively(Tag, tags)

    # 2. Map entities with simple relationships
    line_mapper = mapper_registry.map_imperatively(OrderLine, order_lines)

    # 3. Map aggregate roots with relationships
    mapper_registry.map_imperatively(
        Order, orders,
        properties={
            "lines": relationship(line_mapper),
            "tags": relationship(Tag, secondary=order_tags),
        },
    )
```

## Common Mistakes

- **Calling `start_mappers()` more than once.** Guard with a flag or use `try/except` if your test setup might call it multiple times. Better: use `clear_mappers()` in test teardown.
- **Importing SQLAlchemy in domain code.** Even `from sqlalchemy import Column` in `model.py` violates the dependency direction. Everything ORM-related stays in `adapters/orm.py`.
- **Mapping order wrong.** If you reference `OrderLine` in a relationship before mapping it, you get errors. Map children first.
- **Forgetting `collection_class=list`.** Without it, collections default to `InstrumentedList` which works like a list but may behave differently in edge cases. Being explicit is safer.

## Optimistic Concurrency (Version Columns)

Cosmic Python aggregates use version numbers to prevent lost updates from concurrent modifications. SQLAlchemy has built-in support via `version_id_col`.

### Automatic Version Tracking

```python
# In the table definition
products = Table(
    "products", metadata,
    Column("sku", String(255), primary_key=True),
    Column("name", String(255)),
    Column("version_number", Integer, nullable=False, server_default="0"),
)

# In the mapper — SQLAlchemy manages the version automatically
mapper_registry.map_imperatively(
    Product, products,
    version_id_col=products.c.version_number,
)
```

With `version_id_col`, SQLAlchemy automatically:
- Increments the version on every UPDATE
- Adds `WHERE version_number = :expected` to UPDATE statements
- Raises `StaleDataError` if the row was modified by another transaction

### How It Works

```python
# Transaction 1 loads product (version=1)
product = session.get(Product, "SKU-001")  # version_number=1

# Transaction 2 modifies the same product (version becomes 2)
# ...

# Transaction 1 tries to save — fails because version changed
product.name = "New Name"
session.commit()
# Raises: sqlalchemy.orm.exc.StaleDataError
# UPDATE products SET name=:name, version_number=2
#   WHERE sku=:sku AND version_number=1
# 0 rows matched — stale!
```

### Manual Version Checking (Without version_id_col)

If you prefer explicit control:

```python
def update_product(sku: str, new_name: str, expected_version: int,
                   uow: AbstractUnitOfWork):
    with uow:
        product = uow.products.get(sku)
        if product.version_number != expected_version:
            raise StaleDataError(f"Product {sku} was modified concurrently")
        product.name = new_name
        product.version_number += 1
        uow.commit()
```

### Concurrency in Aggregates

Set `version_id_col` on aggregate root tables. Internal entities don't need their own version — changes to children go through the root, which increments its version.

```python
# Only the aggregate root has a version column
mapper_registry.map_imperatively(
    Order, orders,
    version_id_col=orders.c.version_number,
    properties={
        "_items": relationship(OrderLine, cascade="all, delete-orphan"),
    },
)
# Adding/removing OrderLines triggers Order's version increment
```

## Testing

```python
# conftest.py
from sqlalchemy import create_engine
from sqlalchemy.orm import clear_mappers, sessionmaker

@pytest.fixture(scope="session")
def engine():
    return create_engine("sqlite:///:memory:")

@pytest.fixture(scope="session", autouse=True)
def mappers(engine):
    metadata.create_all(engine)
    start_mappers()
    yield
    clear_mappers()

@pytest.fixture
def session(engine):
    connection = engine.connect()
    transaction = connection.begin()
    session = sessionmaker(bind=connection)()
    yield session
    session.close()
    transaction.rollback()
    connection.close()
```

Use `clear_mappers()` in teardown to allow re-mapping in test suites.
