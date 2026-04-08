# Testing with SQLAlchemy

## When to Use

You're setting up test fixtures for a Cosmic Python project using SQLAlchemy. Integration tests need a real database (usually in-memory SQLite), proper session management, and mapper setup/teardown.

## The Standard Test Setup

```python
# tests/conftest.py
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, clear_mappers

from adapters.orm import metadata, start_mappers


@pytest.fixture(scope="session")
def engine():
    """One engine for the entire test session."""
    return create_engine("sqlite:///:memory:")


@pytest.fixture(scope="session", autouse=True)
def tables(engine):
    """Create all tables once, before any tests run."""
    metadata.create_all(engine)
    start_mappers()
    yield
    clear_mappers()


@pytest.fixture
def session(engine):
    """Fresh session per test, with transaction rollback for isolation."""
    connection = engine.connect()
    transaction = connection.begin()
    session = sessionmaker(
        bind=connection,
        expire_on_commit=False,
    )()
    yield session
    session.close()
    transaction.rollback()
    connection.close()
```

### Why This Pattern Works

- **`scope="session"` for engine and tables:** Create the database once, not per test. Much faster.
- **Transaction rollback per test:** Each test runs in a transaction that gets rolled back. Tests don't see each other's data. No need to truncate tables.
- **`expire_on_commit=False`:** Matches production behavior (see `session-and-uow.md`).
- **`clear_mappers()` in teardown:** Allows re-mapping if needed. Prevents `ArgumentError` from duplicate mappings.

## FakeUnitOfWork for Service Layer Tests

Most tests should use `FakeUnitOfWork` — no database at all:

```python
class FakeUnitOfWork:
    def __init__(self):
        self.products = FakeProductRepository()
        self.orders = FakeOrderRepository()
        self.committed = False

    def __enter__(self):
        return self

    def __exit__(self, *args):
        pass

    def commit(self):
        self.committed = True

    def rollback(self):
        pass


class FakeProductRepository:
    def __init__(self, products=None):
        self._products = set(products or [])
        self.seen = set()

    def add(self, product):
        self._products.add(product)
        self.seen.add(product)

    def get(self, sku):
        product = next((p for p in self._products if p.sku == sku), None)
        if product:
            self.seen.add(product)
        return product
```

## Integration Test for Repository

```python
def test_repository_can_save_and_retrieve(session):
    repo = SqlAlchemyProductRepository(session)
    product = Product("SKU-001", "Widget", Money(100, "USD"))
    repo.add(product)
    session.commit()

    # Expire to force a fresh load from DB
    session.expire_all()

    loaded = repo.get("SKU-001")
    assert loaded.sku == "SKU-001"
    assert loaded.name == "Widget"


def test_repository_returns_none_for_missing(session):
    repo = SqlAlchemyProductRepository(session)
    assert repo.get("NONEXISTENT") is None
```

## Integration Test for UoW

```python
@pytest.fixture
def uow(session):
    """UoW backed by the test session."""
    class TestUnitOfWork(SqlAlchemyUnitOfWork):
        def __init__(self, session):
            self._session = session

        def __enter__(self):
            self.session = self._session
            self.products = SqlAlchemyProductRepository(self.session)
            return self

        def __exit__(self, *args):
            pass  # Don't close — let the fixture handle rollback

    return TestUnitOfWork(session)


def test_uow_can_add_and_commit(uow):
    with uow:
        product = Product("SKU-001", "Widget", Money(100, "USD"))
        uow.products.add(product)
        uow.commit()

    with uow:
        loaded = uow.products.get("SKU-001")
        assert loaded is not None
```

## Testing with PostgreSQL (for CI)

In-memory SQLite is fast but doesn't catch dialect-specific issues. For CI, use a real PostgreSQL:

```python
@pytest.fixture(scope="session")
def engine():
    url = os.environ.get(
        "TEST_DATABASE_URL",
        "sqlite:///:memory:",  # Fallback for local dev
    )
    return create_engine(url)
```

Set `TEST_DATABASE_URL=postgresql://user:pass@localhost/test_db` in CI.

## Testing ORM Mappings

Verify that your imperative mapping round-trips correctly:

```python
def test_order_line_mapper_can_save_and_load(session):
    session.execute(text(
        "INSERT INTO orders (order_id, customer_id) VALUES ('ORD-1', 'CUST-1')"
    ))
    session.execute(text(
        "INSERT INTO order_lines (sku, qty, order_id) "
        "VALUES ('SKU-1', 5, 'ORD-1')"
    ))
    session.commit()

    order = session.scalars(
        select(Order)
        .where(Order.order_id == "ORD-1")
        .options(selectinload(Order._items))
    ).one()

    assert len(order.items) == 1
    assert order.items[0].sku == "SKU-1"
    assert order.items[0].qty == 5
```

## Common Mistakes

- **Calling `start_mappers()` per test.** Use `scope="session"` and call once. Use `clear_mappers()` for teardown.
- **Not rolling back transactions.** Tests pollute each other's data. Use the transaction-per-test pattern.
- **Testing with `FakeUnitOfWork` everywhere.** Fakes are great for service-layer tests, but you still need integration tests to verify ORM mappings actually work.
- **Forgetting `expire_on_commit=False` in test sessions.** Behavior should match production.
- **Using `session.query()` in tests.** Even in test code, use 2.0-style `select()` + `scalars()` to stay consistent.

## Testing Pyramid Reminder

| Layer | SQLAlchemy involvement | Test type |
|---|---|---|
| Domain model | None | Pure unit tests |
| Service layer | `FakeUnitOfWork` | Fast unit tests |
| Repository | Real `Session` + in-memory SQLite | Integration tests |
| ORM mapping | Real `Session` + in-memory SQLite | Integration tests |
| API endpoints | Full stack | E2E (1-2 per endpoint) |
