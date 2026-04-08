# Adoption Guide: Legacy Migration

## When to Use

You have an existing Python application (Django, Flask, or plain scripts) and want to adopt Cosmic Python patterns incrementally. You don't want (or can't afford) a full rewrite.

## The Migration Order

Adopt patterns in this order. Each step is independently valuable — you can stop at any point.

```
1. Service Layer  →  2. Aggregates  →  3. Events  →  4. CQRS
   (highest ROI)        (if needed)      (if needed)    (if needed)
```

### Step 1: Extract a Service Layer (Start Here)

The highest-value, lowest-risk change. Identify use cases in your existing code and extract them into service functions.

**Before:**
```python
# views.py (Django) — logic scattered in view
def create_order(request):
    customer = Customer.objects.get(id=request.data["customer_id"])
    if customer.is_banned:
        return Response({"error": "banned"}, 400)
    order = Order.objects.create(customer=customer)
    for item in request.data["items"]:
        product = Product.objects.get(sku=item["sku"])
        if product.stock < item["qty"]:
            return Response({"error": "out of stock"}, 400)
        OrderLine.objects.create(order=order, product=product, qty=item["qty"])
        product.stock -= item["qty"]
        product.save()
    send_confirmation_email(customer.email, order.id)
    return Response({"order_id": order.id}, 201)
```

**After:**
```python
# service_layer/handlers.py — use case extracted
def create_order(customer_id: str, items: list[dict]):
    customer = Customer.objects.get(id=customer_id)
    if customer.is_banned:
        raise CustomerBanned(customer_id)
    order = Order.objects.create(customer=customer)
    for item in items:
        product = Product.objects.get(sku=item["sku"])
        if product.stock < item["qty"]:
            raise OutOfStock(item["sku"])
        OrderLine.objects.create(order=order, product=product, qty=item["qty"])
        product.stock -= item["qty"]
        product.save()
    send_confirmation_email(customer.email, order.id)
    return order.id

# views.py — thin wrapper
def create_order_view(request):
    try:
        order_id = handlers.create_order(**request.data)
        return Response({"order_id": order_id}, 201)
    except CustomerBanned:
        return Response({"error": "banned"}, 400)
    except OutOfStock as e:
        return Response({"error": str(e)}, 400)
```

Even without Repository or UoW, this dramatically improves testability and clarity.

### Step 2: Identify Aggregates

Look at your service functions. Which objects are always modified together? Those are your aggregates.

**Signals:**
- Replace direct object references with identifiers (e.g., `order.customer` → `order.customer_id`)
- Break bidirectional relationships (they signal wrong aggregate boundaries)
- If you modify two objects in the same transaction, they might be one aggregate

### Step 3: Extract Domain Events

Find "when X happens, do Y" patterns in your service functions:

```python
# Before — tightly coupled
def create_order(customer_id, items):
    order = Order.create(customer_id)
    # ... create order ...
    send_confirmation_email(customer.email, order.id)  # ← side effect
    update_analytics("order_created", order.id)        # ← side effect
    notify_warehouse(order)                             # ← side effect

# After — decoupled via events
def create_order(customer_id, items, uow):
    with uow:
        order = Order.create(customer_id)  # emits OrderCreated event
        uow.orders.add(order)
        uow.commit()
    # Event handlers handle email, analytics, warehouse separately
```

### Step 4: Add CQRS (If Needed)

Only if read performance is actually a problem. Start by separating read functions from write functions. Then optimize the read path independently.

## Practical Advice

**Link refactoring to feature work.** Don't pitch "we need to refactor." Pitch "this 6-month feature will take 3 extra weeks of cleanup, and here's why it's worth it." Framing it as "architecture tax" helps stakeholders understand.

**Deploy walking skeletons.** Handle one event end-to-end before building out the full system. This forces you to answer infrastructure questions (message broker, deployment, monitoring) before you're deep in business logic.

**Accept temporary duplication.** During migration, you'll have old code and new code side by side. That's fine. Don't demand perfection during the transition.

**Don't try to adopt everything at once.** Each pattern is independently useful. A service layer without a repository still helps. A repository without events still helps.

## Critical Warnings

- **Idempotency is non-optional.** If you add events, every handler must be safe to retry. This is not a "nice to have."
- **Redis pub/sub is unreliable for production events.** Messages are lost if no subscriber is listening. Use RabbitMQ, Kafka, or an event store for production systems.
- **Version your event schemas from the start.** Events are contracts between producers and consumers. Changing the shape of `OrderCreated` after it's in production is painful.
- **Never call use cases from other use cases.** Use the message bus. If `create_order` calls `update_inventory` directly, they're coupled. If `create_order` emits `OrderCreated` and a handler calls `update_inventory`, they're decoupled.

## Testing During Migration

You can test incrementally too:

```python
# Step 1: Service function tests (even with Django ORM)
def test_create_order_rejects_banned_customer():
    Customer.objects.create(id="CUST-001", is_banned=True)
    with pytest.raises(CustomerBanned):
        handlers.create_order("CUST-001", items=[])

# Step 2: After adding fakes
def test_create_order_with_fake_uow():
    uow = FakeUnitOfWork()
    uow.customers = FakeRepo([Customer("CUST-001", is_banned=True)])
    with pytest.raises(CustomerBanned):
        handlers.create_order("CUST-001", items=[], uow=uow)
```

Each migration step makes your code more testable, which makes the next step easier.
