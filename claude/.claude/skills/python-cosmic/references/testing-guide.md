# Testing Guide

## The Testing Pyramid

Most tests should be fast and focused. Few tests should be slow and broad.

```
         /\
        /  \    E2E tests (1-2 per use case)
       / e2e\   Real HTTP + real DB
      /------\
     /        \  Service layer tests (bulk of tests)
    / service  \ FakeUnitOfWork + FakeRepository
   /   layer   \
  /--------------\
 /                \ Domain tests (many, fast)
/  domain model    \ Plain Python, no fakes needed
/--------------------\
```

If you're writing lots of E2E tests, push them down to service-layer tests. If you're writing lots of service-layer tests with complex setup, push them down to domain tests.

## What to Test at Each Layer

### Domain Model Tests

**What:** Business rules, invariants, domain logic, event generation.
**How:** Instantiate domain objects, call methods, assert results. No fakes, no database, no setup.
**Speed:** Fastest — milliseconds per test.

```python
def test_order_rejects_negative_quantity():
    order = Order("ORD-001", "CUST-001")
    with pytest.raises(InvalidQuantity):
        order.add_item("SKU-001", qty=-1, unit_price=Money(100, "USD"))

def test_order_total_sums_line_items():
    order = Order("ORD-001", "CUST-001")
    order.add_item("SKU-001", qty=2, unit_price=Money(500, "USD"))
    order.add_item("SKU-002", qty=1, unit_price=Money(300, "USD"))
    assert order.total == Money(1300, "USD")

def test_shipping_order_emits_event():
    order = Order("ORD-001", "CUST-001")
    order.status = OrderStatus.PAID
    order.ship()
    assert order.events[-1] == OrderShipped("ORD-001")
```

**Guidelines:**
- Test names describe business behavior, not implementation
- Variable names use business language
- No setup beyond creating domain objects
- These tests are your specification — a domain expert should understand them

### Service Layer Tests

**What:** Use case orchestration, error handling, handler interactions.
**How:** `FakeUnitOfWork` + `FakeRepository`. No database, no HTTP.
**Speed:** Fast — milliseconds per test.

```python
@pytest.fixture
def uow():
    return FakeUnitOfWork()

def test_create_order_persists_and_commits(uow):
    uow.products = FakeProductRepository([
        Product("SKU-001", "Widget", Money(100, "USD"))
    ])
    result = handlers.create_order(
        customer_id="CUST-001",
        items=[{"sku": "SKU-001", "qty": 2}],
        uow=uow,
    )
    assert result is not None
    assert uow.committed

def test_create_order_rejects_unknown_product(uow):
    with pytest.raises(UnknownProduct):
        handlers.create_order(
            customer_id="CUST-001",
            items=[{"sku": "NONEXISTENT", "qty": 1}],
            uow=uow,
        )
    assert not uow.committed

def test_create_order_rolls_back_on_domain_error(uow):
    uow.products = FakeProductRepository([
        Product("SKU-001", "Widget", Money(100, "USD"))
    ])
    with pytest.raises(InvalidQuantity):
        handlers.create_order(
            customer_id="CUST-001",
            items=[{"sku": "SKU-001", "qty": -1}],
            uow=uow,
        )
    assert not uow.committed
```

**Guidelines:**
- This is where the bulk of your tests live
- Test happy paths AND error paths
- Verify commit/rollback behavior
- Use `FakeUnitOfWork` — never hit the database here

### Adapter / Integration Tests

**What:** ORM mapping round-trips, repository save/load, real database operations.
**How:** Integration tests with a real database (SQLite in-memory for speed, or the real DB for confidence).
**Speed:** Slow — seconds per test.

```python
@pytest.fixture
def session(sqlite_session_factory):
    session = sqlite_session_factory()
    yield session
    session.close()

def test_repository_can_save_and_retrieve_product(session):
    repo = SqlAlchemyProductRepository(session)
    product = Product("SKU-001", "Widget", Money(100, "USD"))
    repo.add(product)
    session.commit()

    retrieved = repo.get("SKU-001")
    assert retrieved.sku == "SKU-001"
    assert retrieved.name == "Widget"

def test_repository_returns_none_for_missing_product(session):
    repo = SqlAlchemyProductRepository(session)
    assert repo.get("NONEXISTENT") is None
```

**Guidelines:**
- Only test the mapping and persistence — not business logic
- Use a real database (in-memory SQLite is fine for speed)
- Keep these tests minimal — one per significant mapping

### E2E / API Tests

**What:** Happy path through the full stack. One error path.
**How:** Real HTTP requests against the running app, real database.
**Speed:** Slowest.

```python
def test_create_order_happy_path(client, seed_products):
    response = client.post("/orders", json={
        "customer_id": "CUST-001",
        "items": [{"sku": "SKU-001", "qty": 2}],
    })
    assert response.status_code == 201
    assert "order_id" in response.json

def test_create_order_unknown_product(client):
    response = client.post("/orders", json={
        "customer_id": "CUST-001",
        "items": [{"sku": "NONEXISTENT", "qty": 1}],
    })
    assert response.status_code == 400
```

**Guidelines:**
- One happy path + one error path per use case. That's it.
- These tests verify that the entrypoint, service layer, and database are wired together
- If you need more than this, push the tests down to the service layer

## Fake Patterns

### FakeRepository

```python
class FakeProductRepository(AbstractProductRepository):
    def __init__(self, products=None):
        super().__init__()
        self._products = set(products or [])

    def _add(self, product):
        self._products.add(product)

    def _get(self, sku):
        return next((p for p in self._products if p.sku == sku), None)
```

### FakeUnitOfWork

```python
class FakeUnitOfWork(AbstractUnitOfWork):
    def __init__(self):
        self.products = FakeProductRepository()
        self.orders = FakeOrderRepository()
        self.committed = False

    def _commit(self):
        self.committed = True

    def rollback(self):
        pass
```

### Principle: Fake Code You Own

"Don't mock what you don't own." We don't mock SQLAlchemy sessions or requests — we fake the abstractions we created (Repository, UoW). If the fake is hard to write, the abstraction is too complex.

## Test Data

Set up data through the same path it takes in production:

```python
# GOOD — uses the message bus
def test_order_view(bus):
    bus.handle(commands.CreateOrder(
        customer_id="CUST-001",
        items=[{"sku": "SKU-001", "qty": 2}],
    ))
    result = views.order_summary("ORD-001", bus.uow)
    assert result["item_count"] == 1

# BAD — inserts directly into database
def test_order_view(session):
    session.execute(text("INSERT INTO orders ..."))
    # Bypasses domain logic, may create invalid state
```

## Common Mistakes

- **Testing at the wrong level.** Business rule in a domain test → fast. Business rule in an E2E test → slow. Same coverage, different cost.
- **Mocking everything.** If your test has 5 mocks and no assertions on real behavior, you're testing mock behavior, not your code.
- **Testing implementation details.** "assert len(mock_repo.add.call_args_list) == 1" tells you nothing about correctness. Test outcomes, not calls.
- **Slow test suite.** If tests take minutes, you'll stop running them. Push tests down the pyramid.
- **No tests on event generation.** Domain events are part of the contract. Test that the right events are emitted.
