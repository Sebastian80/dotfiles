# CQRS (Command-Query Responsibility Segregation)

## When to Use

Your read-side requirements differ significantly from your write-side model. Complex queries are slow through the domain model. You're joining multiple aggregates for a view. Read performance is a problem.

## When NOT to Use

If your reads and writes use the same shape of data and performance is fine, CQRS adds complexity without benefit. Start without it and add when you feel the pain.

## The Core Idea

Reads and writes use different models. The write side uses the full domain model with aggregates, repositories, and business rules. The read side uses optimized, denormalized views.

This means accepting a fundamental truth: **data is already stale the moment you render it.** A user looking at a webpage is looking at a snapshot from the past. Build your reads accordingly.

## Five Levels of Complexity

Start at level 1. Only move up when performance demands it.

### Level 1: Existing ORM for reads (start here)

```python
# views.py
def order_summary(order_id: str, uow: AbstractUnitOfWork):
    with uow:
        order = uow.orders.get(order_id)
        return {
            "order_id": order.order_id,
            "customer_id": order.customer_id,
            "total": order.total.amount,
            "item_count": len(order.items),
        }
```

Simple, uses existing infrastructure. Good enough for most applications.

### Level 2: Custom ORM queries

```python
def order_list(customer_id: str, session):
    return session.query(Order).filter_by(
        customer_id=customer_id
    ).options(
        joinedload(Order._items)  # Avoid N+1
    ).all()
```

### Level 3: Hand-rolled SQL

```python
def order_list(customer_id: str, session):
    results = session.execute(text(
        """
        SELECT o.order_id, o.customer_id,
               COUNT(li.id) as item_count,
               SUM(li.qty * li.unit_price) as total
        FROM orders o
        JOIN line_items li ON li.order_id = o.order_id
        WHERE o.customer_id = :customer_id
        GROUP BY o.order_id, o.customer_id
        """
    ), {"customer_id": customer_id})
    return [dict(r._mapping) for r in results]
```

Faster, avoids ORM overhead, but now you have raw SQL to maintain.

### Level 4: Denormalized read tables updated via events

```python
# A separate table optimized for reads
order_summaries = Table(
    "order_summaries", metadata,
    Column("order_id", String(255), primary_key=True),
    Column("customer_id", String(255)),
    Column("total", Integer),
    Column("item_count", Integer),
    Column("status", String(50)),
)

# Event handler keeps it updated
def update_order_summary(event: events.OrderCreated, uow):
    with uow:
        session.execute(text(
            "INSERT INTO order_summaries ..."
        ))
        uow.commit()
```

### Level 5: Separate read store

Redis, Elasticsearch, or a materialized view in a different database. The ultimate performance optimization, but the most complex to maintain.

## Implementation Rules

1. **Read operations NEVER trigger writes.** Views are pure functions — they read data and return it. No side effects.

2. **Accept eventual consistency.** The read model might lag behind the write model by milliseconds or seconds. That's fine.

3. **Always build rebuild capability.** If your read model gets corrupted, you need to be able to replay events (or re-query the write model) to reconstruct it. Never let the read model be the only copy of data.

4. **Start simple, scale up.** Most applications never need beyond Level 2. Don't add complexity preemptively.

## Common Mistakes

- **Reusing the domain model for reads.** Loading a full aggregate graph just to show a summary wastes memory and time. Build a dedicated read path.
- **SELECT N+1 from ORM lazy loading.** When using ORM for reads, always use `joinedload` or `subqueryload` to prevent N+1 queries.
- **Over-normalizing read models.** Read models should be shaped for the query, not for normalized storage. Denormalize aggressively.
- **No error handling for read model updates.** If an event handler that updates a read table fails, the read model goes stale. Build monitoring and rebuild capability.
- **Treating reads and writes symmetrically.** They have different performance profiles, different consistency requirements, and different scaling needs. Embrace the asymmetry.

## Testing

Set up data through the write side (message bus / commands), then assert against view functions. This lets you swap read implementations without changing tests:

```python
def test_order_summary_view(bus):
    bus.handle(commands.CreateOrder(
        customer_id="CUST-001",
        items=[{"sku": "SKU-001", "qty": 2, "price": 500}],
    ))
    summary = views.order_summary("ORD-001", bus.uow)
    assert summary["customer_id"] == "CUST-001"
    assert summary["total"] == 1000
    assert summary["item_count"] == 1
```
