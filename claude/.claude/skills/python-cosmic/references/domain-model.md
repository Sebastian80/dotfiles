# Domain Model

## When to Use

You're modeling business concepts that have rules, constraints, and behavior beyond simple data storage. The domain model is the heart of your application — spend your best design thinking here.

## When NOT to Use

If your "model" is just a bag of data with getters and setters and no business logic, you don't need a domain model — you have a data transfer object. Use a plain dataclass or an ORM model directly.

## Building Blocks

### Value Objects

Identified by their data, not by an ID. Immutable. Two instances with the same data are equal.

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class Money:
    amount: int
    currency: str

@dataclass(frozen=True)
class Address:
    street: str
    city: str
    postal_code: str
    country: str

# Value Object equality is based on data
assert Money(1000, "USD") == Money(1000, "USD")
```

Use `@dataclass(frozen=True)` — it gives you immutability, `__eq__`, and `__hash__` for free.

### Entities

Identified by a persistent identity. Two entities with the same ID are the same thing, even if their other attributes differ. Mutable.

```python
class Order:
    def __init__(self, order_id: str, customer_id: str):
        self.order_id = order_id
        self.customer_id = customer_id
        self._line_items: set[LineItem] = set()
        self.events: list = []

    def __eq__(self, other):
        if not isinstance(other, Order):
            return NotImplemented
        return self.order_id == other.order_id

    def __hash__(self):
        return hash(self.order_id)

    def add_item(self, sku: str, qty: int, unit_price: Money):
        """Encapsulate business rules in methods."""
        if qty <= 0:
            raise InvalidQuantity(f"Quantity must be positive, got {qty}")
        item = LineItem(sku=sku, qty=qty, unit_price=unit_price)
        self._line_items.add(item)

    @property
    def total(self) -> Money:
        """Derive values via @property instead of storing redundant state."""
        total = sum(item.subtotal.amount for item in self._line_items)
        currency = next(iter(self._line_items)).unit_price.currency
        return Money(total, currency)
```

### Domain Services

Standalone functions for business operations that don't belong to a single entity. Don't confuse these with service-layer functions — domain services express business concepts, service-layer functions orchestrate use cases.

```python
# domain/model.py — this IS a domain service (business logic)
def allocate(line: OrderLine, batches: list[Batch]) -> str:
    try:
        batch = next(b for b in sorted(batches) if b.can_allocate(line))
        batch.allocate(line)
        return batch.reference
    except StopIteration:
        raise OutOfStock(f"Out of stock for sku {line.sku}")
```

## Implementation Rules

1. **Zero infrastructure imports.** No SQLAlchemy, no Flask, no Django, no `requests`. The domain model is pure Python. This is non-negotiable — even "just one import" breaks the dependency direction.

2. **Encapsulate business rules in methods.** Write `order.add_item(sku, qty, price)` not `order.items.append(LineItem(...))`. The model enforces its own invariants.

3. **Raise domain-specific exceptions.** Define exceptions that use business language: `OutOfStock`, `InvalidQuantity`, `OrderAlreadyShipped`. Never raise generic `ValueError` for domain violations.

4. **Use Python magic methods to express domain semantics.** `__eq__` for identity, `__hash__` for set membership, `__gt__`/`__lt__` for domain ordering (e.g., batches ordered by ETA).

5. **Use `@property` for derived values.** Don't store `total` as a field when it can be computed from line items. Fewer fields = fewer consistency bugs.

6. **Use `set()` for uniqueness invariants.** If a line item can only be added once, store line items in a set. The data structure enforces the rule.

7. **Record domain events instead of calling infrastructure.** When something noteworthy happens, append an event to `self.events`. Don't call email services or message queues from the domain model.

## Common Mistakes

- **Anemic domain model.** All data, no behavior. If your entity is just `@dataclass` fields with no methods, the business logic leaked into the service layer.
- **Over-engineering with `NewType` wrappers.** `OrderId = NewType('OrderId', str)` adds complexity without meaningful type safety in Python. Use plain `str` unless you have a compelling reason.
- **Silent failures.** `add_item` returning `None` on invalid input instead of raising an exception. Fail loudly with domain exceptions.
- **Infrastructure leaking in.** Importing `datetime.utcnow()` is fine (stdlib). Importing `sqlalchemy.Column` is not. The test: can you run your domain tests without installing any infrastructure packages?

## Testing

Domain model tests are the fastest and most valuable tests in the system. They need no fakes, no database, no setup — just instantiate domain objects and assert behavior.

```python
def test_order_rejects_zero_quantity():
    order = Order("ORD-001", "CUST-001")
    with pytest.raises(InvalidQuantity):
        order.add_item("SKU-001", qty=0, unit_price=Money(100, "USD"))

def test_order_calculates_total():
    order = Order("ORD-001", "CUST-001")
    order.add_item("SKU-001", qty=2, unit_price=Money(500, "USD"))
    order.add_item("SKU-002", qty=1, unit_price=Money(300, "USD"))
    assert order.total == Money(1300, "USD")
```

Test names describe business behavior. Variable names use business language. A domain expert should be able to read these tests and understand what they verify.
