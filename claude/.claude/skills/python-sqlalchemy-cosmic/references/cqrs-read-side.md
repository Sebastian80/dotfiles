# CQRS Read Side with SQLAlchemy Core

## When to Use

You're building CQRS read models in a Cosmic Python project. The write side uses the ORM (domain model + repository + UoW). The read side bypasses the ORM entirely and uses SQLAlchemy Core or raw SQL for optimized, denormalized queries.

This is the bridge between the `cosmic-python` skill's CQRS reference and actual SQLAlchemy implementation.

## Why Core for Reads?

The ORM is designed for write-side concerns: identity tracking, change detection, relationship navigation. For reads you want:
- Denormalized data shaped for the view, not the domain
- No ORM overhead (no identity map, no change tracking)
- JOINs and aggregations that don't map to any domain entity
- Fast, direct SQL

## Pattern 1: Raw SQL View Functions

The simplest approach — `text()` queries in view functions:

```python
# views.py — CQRS read side
from sqlalchemy import text

def order_summary(order_id: str, uow):
    with uow:
        result = uow.session.execute(text("""
            SELECT o.order_id, o.customer_id, o.status,
                   COUNT(li.id) AS item_count,
                   SUM(li.qty * li.unit_price) AS total
            FROM orders o
            LEFT JOIN order_lines li ON li.order_id = o.order_id
            WHERE o.order_id = :order_id
            GROUP BY o.order_id, o.customer_id, o.status
        """), {"order_id": order_id})
        row = result.mappings().one_or_none()
        return dict(row) if row else None


def orders_for_customer(customer_id: str, uow):
    with uow:
        results = uow.session.execute(text("""
            SELECT o.order_id, o.status,
                   COUNT(li.id) AS item_count,
                   SUM(li.qty * li.unit_price) AS total
            FROM orders o
            LEFT JOIN order_lines li ON li.order_id = o.order_id
            WHERE o.customer_id = :customer_id
            GROUP BY o.order_id, o.status
            ORDER BY o.created_at DESC
        """), {"customer_id": customer_id})
        return [dict(r) for r in results.mappings()]
```

### Why `uow.session` and not `engine.connect()`?

In the Cosmic Python architecture, the UoW owns the database session. Using the same session for reads means you see uncommitted changes from the current transaction — which is usually what you want for consistency within a request.

For truly independent read replicas, use a separate engine/connection.

## Pattern 2: Core Expression Language Views

Type-safe queries using Table objects directly (no ORM classes):

```python
# views.py
from sqlalchemy import select, func
from adapters.orm import orders, order_lines  # Table objects, not domain classes

def order_summary(order_id: str, uow):
    stmt = (
        select(
            orders.c.order_id,
            orders.c.customer_id,
            orders.c.status,
            func.count(order_lines.c.id).label("item_count"),
            func.coalesce(
                func.sum(order_lines.c.qty * order_lines.c.unit_price), 0
            ).label("total"),
        )
        .outerjoin(order_lines, orders.c.order_id == order_lines.c.order_id)
        .where(orders.c.order_id == order_id)
        .group_by(orders.c.order_id, orders.c.customer_id, orders.c.status)
    )
    with uow:
        row = uow.session.execute(stmt).mappings().one_or_none()
        return dict(row) if row else None
```

This approach gives you column type safety and IDE autocomplete while avoiding ORM overhead.

## Pattern 3: Denormalized Read Tables

For high-read-volume views, maintain a separate denormalized table updated via domain events:

```python
# adapters/orm.py — add read model table
order_summaries = Table(
    "order_summaries", metadata,
    Column("order_id", String(255), primary_key=True),
    Column("customer_id", String(255), index=True),
    Column("status", String(50)),
    Column("item_count", Integer, default=0),
    Column("total", Integer, default=0),  # cents
    Column("last_updated", DateTime),
)
```

```python
# service_layer/handlers.py — event handler updates read model
from sqlalchemy import insert, update
from adapters.orm import order_summaries

def update_order_summary(event: events.OrderCreated, uow):
    with uow:
        uow.session.execute(
            insert(order_summaries).values(
                order_id=event.order_id,
                customer_id=event.customer_id,
                status="pending",
                item_count=len(event.items),
                total=event.total,
                last_updated=func.now(),
            )
        )
        uow.commit()

def update_order_status_in_summary(event: events.OrderShipped, uow):
    with uow:
        uow.session.execute(
            update(order_summaries)
            .where(order_summaries.c.order_id == event.order_id)
            .values(status="shipped", last_updated=func.now())
        )
        uow.commit()
```

```python
# views.py — reads are now trivial
def order_summary(order_id: str, uow):
    with uow:
        row = uow.session.execute(
            select(order_summaries).where(
                order_summaries.c.order_id == order_id
            )
        ).mappings().one_or_none()
        return dict(row) if row else None
```

### Rebuild Capability

Always build the ability to reconstruct read models from scratch:

```python
def rebuild_order_summaries(uow):
    """Drop and rebuild all order summaries from source data."""
    with uow:
        uow.session.execute(delete(order_summaries))
        uow.session.execute(
            insert(order_summaries).from_select(
                ["order_id", "customer_id", "status", "item_count", "total"],
                select(
                    orders.c.order_id,
                    orders.c.customer_id,
                    orders.c.status,
                    func.count(order_lines.c.id),
                    func.coalesce(func.sum(order_lines.c.qty * order_lines.c.unit_price), 0),
                )
                .outerjoin(order_lines)
                .group_by(orders.c.order_id, orders.c.customer_id, orders.c.status)
            )
        )
        uow.commit()
```

## Choosing Your Approach

| Approach | When | Complexity |
|---|---|---|
| Raw SQL (`text()`) | Quick, low-traffic views | Low |
| Core Expression Language | Type-safe queries, moderate traffic | Medium |
| Denormalized read tables | High-traffic views, complex aggregations | High |

Start with raw SQL. Graduate to Core expressions when you want type safety. Add denormalized tables only when read performance demands it.

## Common Mistakes

- **Using ORM `select(Order)` for read models.** This loads the full domain object with identity tracking. Use `select(orders.c.id, orders.c.status)` (table columns) or `text()` for reads.
- **Forgetting `.mappings()` on results.** Without it, you get `Row` tuples. With it, you get dict-like access.
- **Not building rebuild capability.** If event handlers fail and the read model gets stale, you need a way to reconstruct it.
- **Updating read models in the command handler.** Keep read model updates in event handlers. The command handler should only modify the write-side aggregate.

## Testing Read Models

Set up data through the write side (commands), then assert on view functions:

```python
def test_order_summary_view(bus):
    bus.handle(commands.CreateOrder(
        customer_id="CUST-001",
        items=[{"sku": "SKU-001", "qty": 2, "price": 500}],
    ))
    summary = views.order_summary("ORD-001", bus.uow)
    assert summary["customer_id"] == "CUST-001"
    assert summary["item_count"] == 1
    assert summary["total"] == 1000
```

This tests the full pipeline: command → domain → events → read model update → view query.
