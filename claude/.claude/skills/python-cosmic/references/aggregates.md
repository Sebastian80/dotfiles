# Aggregates

## When to Use

You have a cluster of domain objects that must be consistent with each other. An aggregate defines a consistency boundary — objects inside must be consistent at the end of every transaction. Objects outside the boundary can be eventually consistent.

## When NOT to Use

If every entity is independent and has no cross-entity invariants, you don't need aggregates. Each entity can be its own repository. You also don't need aggregates for read-only views.

## Implementation Rules

1. **One repository per aggregate.** Repositories return aggregate roots, never internal entities. If you need a `LineItem` directly, it's probably not part of the `Order` aggregate — or you need to rethink the boundary.

2. **All modifications go through the root.** Never reach inside an aggregate and mutate children directly. `order.add_item()` is correct. `order.items[0].qty = 5` is a boundary violation.

3. **Load the entire aggregate atomically.** No lazy-loading of internal parts. When you load an `Order`, you get its `LineItems` too. This guarantees you can enforce invariants.

4. **Modify only ONE aggregate per transaction.** This is the fundamental rule. If you need to modify two aggregates in response to one action, the first aggregate emits a domain event, and a separate handler modifies the second.

5. **Keep aggregates small.** Large aggregates kill concurrency — if two users modify different line items on the same order, they'll conflict. If your aggregate has thousands of children, it's too big.

6. **Choose boundaries based on business invariants, not database structure.** A foreign key relationship doesn't mean two tables belong in the same aggregate. Ask: "what invariants must hold at the end of every transaction?"

## Code Example

### Aggregate Root

```python
class Order:
    """Aggregate root — controls access to LineItems."""

    def __init__(self, order_id: str, customer_id: str):
        self.order_id = order_id
        self.customer_id = customer_id
        self._items: list[LineItem] = []
        self.version_number: int = 0
        self.events: list = []

    def add_item(self, sku: str, qty: int, unit_price: Money):
        """All modifications go through the root."""
        if qty <= 0:
            raise InvalidQuantity(qty)
        if len(self._items) >= 100:
            raise TooManyItems("Orders cannot exceed 100 line items")
        self._items.append(LineItem(sku=sku, qty=qty, unit_price=unit_price))

    def remove_item(self, sku: str):
        self._items = [i for i in self._items if i.sku != sku]

    @property
    def total(self) -> Money:
        return Money(
            sum(item.subtotal.amount for item in self._items),
            self._items[0].unit_price.currency if self._items else "USD",
        )

    @property
    def items(self) -> tuple[LineItem, ...]:
        """Expose items as immutable tuple — prevent external mutation."""
        return tuple(self._items)
```

### Optimistic Concurrency

```python
# adapters/orm.py — version column on aggregate root table
orders = Table(
    "orders", metadata,
    Column("order_id", String(255), primary_key=True),
    Column("customer_id", String(255)),
    Column("version_number", Integer, nullable=False, server_default="0"),
)

# In the repository or UoW, use the version for optimistic locking:
# UPDATE orders SET ... WHERE order_id = :id AND version_number = :expected_version
```

When two concurrent transactions try to modify the same aggregate, the second one fails because the version number has changed. This is intentional — retry the operation.

### Cross-Aggregate Communication via Events

```python
class Order:
    def ship(self):
        if self.status != OrderStatus.PAID:
            raise CannotShip("Order must be paid before shipping")
        self.status = OrderStatus.SHIPPED
        # Don't modify Inventory aggregate here!
        # Instead, emit an event for a separate handler:
        self.events.append(events.OrderShipped(self.order_id))

# A separate event handler modifies the Inventory aggregate
def reduce_inventory(event: events.OrderShipped, uow: AbstractUnitOfWork):
    with uow:
        for item in event.items:
            inventory = uow.inventory.get(item.sku)
            inventory.reduce(item.qty)
        uow.commit()
```

## Choosing Aggregate Boundaries

Ask these questions:

1. **What invariants must hold?** "Total order value cannot exceed $10,000" → Order + LineItems are one aggregate.
2. **What can be eventually consistent?** "Inventory counts update after order ships" → Inventory is a separate aggregate, updated via events.
3. **Who modifies what together?** If you always modify A and B in the same transaction, they might be one aggregate.
4. **What's the concurrency profile?** If many users modify the same aggregate concurrently, break it into smaller aggregates.

**Red flags that your aggregate is too big:**
- Loading it requires joining 5+ tables
- Concurrent modification conflicts are frequent
- The aggregate has hundreds of children
- You need to modify two aggregates in one transaction (wrong boundary)

## Common Mistakes

- **Aggregates based on database foreign keys.** Just because `orders` has a FK to `customers` doesn't mean Customer and Order are one aggregate. They almost never are.
- **Exposing internal collections.** Returning `self._items` as a mutable list lets callers bypass the root. Return a copy or a tuple.
- **Modifying multiple aggregates in one transaction.** If you feel the need to do this, either: (a) the boundary is wrong and they should be one aggregate, or (b) use domain events for eventual consistency.
- **Lazy-loading aggregate internals.** If you load an Order without its LineItems and then try to check `order.total`, you'll get wrong results. Load everything atomically.

## Testing

Test aggregates as units — verify that invariants hold and events are emitted:

```python
def test_order_enforces_item_limit():
    order = Order("ORD-001", "CUST-001")
    for i in range(100):
        order.add_item(f"SKU-{i}", qty=1, unit_price=Money(10, "USD"))
    with pytest.raises(TooManyItems):
        order.add_item("SKU-EXTRA", qty=1, unit_price=Money(10, "USD"))

def test_shipping_emits_event():
    order = Order("ORD-001", "CUST-001")
    order.status = OrderStatus.PAID
    order.ship()
    assert order.events == [events.OrderShipped("ORD-001")]
```
