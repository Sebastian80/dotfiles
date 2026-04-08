# Relationships

## When to Use

You're configuring how SQLAlchemy navigates between mapped domain classes — one-to-many, many-to-one, one-to-one, or many-to-many. In Cosmic Python, all relationship configuration lives in `adapters/orm.py`, never in domain classes.

## Relationship Types

### One-to-Many (Most Common)

```python
# Order has many OrderLines
mapper_registry.map_imperatively(
    OrderLine, order_lines,
    properties={
        "order": relationship(Order, back_populates="_items"),
    },
)
mapper_registry.map_imperatively(
    Order, orders,
    properties={
        "_items": relationship(OrderLine, back_populates="order"),
    },
)
```

### Many-to-One

The "many" side has the foreign key. The relationship on the "many" side is scalar (single object), on the "one" side is a collection.

```python
# OrderLine belongs to one Order (scalar side)
properties={"order": relationship(Order, back_populates="_items")}
```

### One-to-One

Same as one-to-many but with `uselist=False` on the parent side:

```python
mapper_registry.map_imperatively(
    User, users,
    properties={
        "profile": relationship(
            UserProfile,
            back_populates="user",
            uselist=False,  # Returns single object, not a list
        ),
    },
)
```

In imperative mapping, `uselist` is **not** auto-detected. You must set it explicitly.

### Many-to-Many

Requires an association table:

```python
order_tags = Table(
    "order_tags", metadata,
    Column("order_id", String, ForeignKey("orders.order_id"), primary_key=True),
    Column("tag_id", Integer, ForeignKey("tags.id"), primary_key=True),
)

mapper_registry.map_imperatively(
    Order, orders,
    properties={
        "tags": relationship(Tag, secondary=order_tags, back_populates="orders"),
    },
)
mapper_registry.map_imperatively(
    Tag, tags,
    properties={
        "orders": relationship(Order, secondary=order_tags, back_populates="tags"),
    },
)
```

## Loading Strategies

### The N+1 Problem

Without eager loading, accessing `order.lines` for each order in a list triggers a separate SQL query per order. This is the N+1 problem.

### Loading Options

| Strategy | When to use | How |
|---|---|---|
| `selectinload()` | Collections (one-to-many). Best default. | Separate `SELECT ... WHERE id IN (...)` |
| `joinedload()` | Scalar relationships (many-to-one). | `JOIN` in the same query |
| `subqueryload()` | Legacy. Use `selectinload()` instead. | Subquery |
| `raiseload()` | Prevent accidental lazy loading | Raises error on access |
| `lazy="raise"` | Same as raiseload, set at mapping time | Prevents N+1 by design |

### Usage in Repository Queries

```python
from sqlalchemy.orm import selectinload, joinedload

class SqlAlchemyOrderRepository:
    def get(self, order_id: str) -> Order:
        return self.session.scalars(
            select(Order)
            .where(Order.order_id == order_id)
            .options(selectinload(Order._items))  # Eager load items
        ).one()

    def get_with_product_details(self, order_id: str) -> Order:
        return self.session.scalars(
            select(Order)
            .where(Order.order_id == order_id)
            .options(
                selectinload(Order._items)
                .joinedload(OrderLine.product)  # Chain loading
            )
        ).one()
```

### The `joinedload()` + `.unique()` Trap

When using `joinedload()` on collections, the SQL JOIN produces duplicate parent rows. You MUST call `.unique()`:

```python
# WRONG — returns duplicate Order objects
orders = session.scalars(
    select(Order).options(joinedload(Order._items))
).all()

# CORRECT — deduplicates
orders = session.scalars(
    select(Order).options(joinedload(Order._items))
).unique().all()
```

This is the #1 SQLAlchemy 2.0 migration pitfall. Use `selectinload()` for collections to avoid this entirely.

## Key Parameters

| Parameter | Purpose | Default |
|---|---|---|
| `back_populates` | Bidirectional sync (preferred) | None |
| `backref` | Legacy. Creates reverse relationship automatically. | None |
| `uselist` | `False` for scalar (one-to-one) | Auto in declarative, manual in imperative |
| `cascade` | Lifecycle management | `"save-update, merge"` |
| `lazy` | Default loading strategy | `"select"` (lazy) |
| `viewonly` | Read-only (no writes through this relationship) | `False` |
| `passive_deletes` | Trust DB `ON DELETE CASCADE` | `False` |
| `collection_class` | `list`, `set`, or custom | `list` |
| `order_by` | Default ordering of collection | None |

## Cascade Options

| Cascade | Behavior |
|---|---|
| `"save-update, merge"` | Default. Adding parent to session includes children. |
| `"all, delete-orphan"` | Full lifecycle. Delete parent → delete children. Remove child from collection → delete orphan. |
| `"all, delete"` | Like above but orphans can exist independently. |

For aggregate roots where children have no meaning outside the parent, use `"all, delete-orphan"`:

```python
properties={
    "_items": relationship(
        OrderLine,
        back_populates="order",
        cascade="all, delete-orphan",
    ),
}
```

## Common Mistakes

- **Using `backref` instead of `back_populates`.** `backref` is legacy. Use `back_populates` with both sides defined explicitly.
- **Forgetting `uselist=False` for one-to-one.** In imperative mapping this is not auto-detected. Without it you get a list.
- **Forgetting `.unique()` with `joinedload()` on collections.** Causes duplicate parent objects in results.
- **Lazy loading in detached objects.** After `session.close()`, accessing a lazy relationship raises `DetachedInstanceError`. Either eager-load what you need, or set `expire_on_commit=False`.
- **Circular dependencies.** If two tables have FKs pointing at each other, use `post_update=True` on one side.

## Testing

Test that relationships load correctly through the repository:

```python
def test_order_loads_with_items(session):
    order = Order("ORD-001", "CUST-001")
    order.add_item("SKU-001", qty=2, unit_price=Money(500, "USD"))
    session.add(order)
    session.commit()

    loaded = session.scalars(
        select(Order)
        .where(Order.order_id == "ORD-001")
        .options(selectinload(Order._items))
    ).one()
    assert len(loaded.items) == 1
    assert loaded.items[0].sku == "SKU-001"
```
