# Service Layer

## When to Use

You need to orchestrate a use case: fetch data, validate preconditions, call domain logic, persist results. The service layer is the boundary between "what the system does" (use cases) and "how the system does it" (domain model + infrastructure).

## When NOT to Use

If your API endpoint is just `save(request.data)` with no validation or domain logic, a service layer is overhead. Call the repository directly from the entrypoint.

## Implementation Rules

1. **One function per use case.** `create_order()`, `cancel_order()`, `ship_order()`. Each function represents one thing the system can do.

2. **Accept primitives, not domain objects.** Service functions take `str`, `int`, `float` — not `Order` or `Money`. This decouples the caller (HTTP, CLI, message queue) from the domain.

3. **Return primitives, not domain objects.** Return `order_id: str`, not `Order`. The caller shouldn't need to understand domain internals.

4. **Delegate ALL business decisions to the domain model.** If you see `if/else` branches making business decisions in a service function, that logic belongs in the domain model. The service layer fetches, calls, and commits.

5. **Accept abstract dependencies as parameters.** Take `uow: AbstractUnitOfWork`, not `SqlAlchemyUnitOfWork`. This enables testing with fakes.

## Code Example

### Service Functions

```python
# service_layer/handlers.py
from domain import model, events

def create_order(customer_id: str, items: list[dict],
                 uow: AbstractUnitOfWork) -> str:
    with uow:
        order = model.Order.create(customer_id)
        for item in items:
            product = uow.products.get(sku=item["sku"])
            if product is None:
                raise model.UnknownProduct(item["sku"])
            order.add_item(product.sku, item["qty"], product.price)
        uow.orders.add(order)
        uow.commit()
    return order.order_id


def cancel_order(order_id: str, uow: AbstractUnitOfWork):
    with uow:
        order = uow.orders.get(order_id)
        if order is None:
            raise model.OrderNotFound(order_id)
        order.cancel()  # Domain logic lives HERE
        uow.commit()
```

### The Pattern

Every service function follows the same shape:

```python
def use_case(input_primitives, uow: AbstractUnitOfWork):
    with uow:
        # 1. Fetch from repository
        aggregate = uow.some_repo.get(id)
        # 2. Validate preconditions (or let domain raise)
        # 3. Execute domain logic
        aggregate.do_something()
        # 4. Commit
        uow.commit()
    return result_primitive
```

### Thin Entrypoint

The API layer should be a thin wrapper — parse HTTP, call service, translate exceptions:

```python
# entrypoints/flask_app.py
@app.route("/orders", methods=["POST"])
def create_order_endpoint():
    try:
        order_id = handlers.create_order(
            customer_id=request.json["customer_id"],
            items=request.json["items"],
            uow=bus.uow,
        )
        return jsonify({"order_id": order_id}), 201
    except model.UnknownProduct as e:
        return jsonify({"error": str(e)}), 400
    except model.OrderNotFound as e:
        return jsonify({"error": str(e)}), 404
```

If your Flask/FastAPI route is doing more than this, logic is in the wrong place.

## The Anemic Domain Model Trap

The service layer's biggest risk is absorbing business logic that belongs in the domain:

```python
# BAD — business logic in service layer
def create_order(customer_id, items, uow):
    with uow:
        order = Order(customer_id)
        total = 0
        for item in items:
            if item["qty"] > 100:  # ← business rule leaked!
                raise TooManyItems()
            total += item["qty"] * item["price"]
        if total > 10000:  # ← business rule leaked!
            order.requires_approval = True
        uow.orders.add(order)
        uow.commit()

# GOOD — service layer delegates to domain
def create_order(customer_id, items, uow):
    with uow:
        order = Order.create(customer_id)  # Domain decides
        for item in items:
            order.add_item(item["sku"], item["qty"])  # Domain validates
        uow.orders.add(order)
        uow.commit()
```

The test: if you removed the service function and called the domain directly, would you lose any business logic? If yes, that logic needs to move into the domain.

## Common Mistakes

- **Business logic in the service layer.** Sorting, filtering, validation, calculations — all domain model concerns.
- **Accepting domain objects as input.** `create_order(order: Order)` couples the caller to the domain. Accept primitives.
- **Returning domain objects.** This leaks domain internals to callers and creates coupling.
- **Fat entrypoints.** If your Flask route has `if/else` logic beyond exception-to-status-code mapping, it's doing too much.
- **Calling service functions from other service functions.** Use the message bus instead — emit an event from one handler, let another handler respond.

## Testing

Most tests target the service layer with fakes. This gives you high coverage without database or HTTP overhead:

```python
def test_create_order_returns_order_id():
    uow = FakeUnitOfWork()
    uow.products = FakeProductRepository([
        Product("SKU-001", "Widget", Money(100, "USD"))
    ])
    order_id = handlers.create_order(
        customer_id="CUST-001",
        items=[{"sku": "SKU-001", "qty": 2}],
        uow=uow,
    )
    assert order_id is not None
    assert uow.committed

def test_create_order_rejects_unknown_product():
    uow = FakeUnitOfWork()
    with pytest.raises(model.UnknownProduct):
        handlers.create_order(
            customer_id="CUST-001",
            items=[{"sku": "NONEXISTENT", "qty": 1}],
            uow=uow,
        )
    assert not uow.committed
```

E2E tests should cover only the happy path and one error path. Everything else is tested at the service layer.
