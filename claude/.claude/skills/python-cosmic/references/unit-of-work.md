# Unit of Work

## When to Use

You need atomic operations — a group of repository calls that either all succeed (commit) or all fail (rollback). The UoW wraps a database session and provides a single entry point to all repositories.

## When NOT to Use

If you have a single repository call per request with no consistency requirements, a UoW adds ceremony without value. Just commit after the repository call.

## Implementation Rules

1. **Context manager with `with` statement.** This makes atomicity visually obvious and guarantees cleanup via `__exit__`.

2. **Explicit commit only.** `uow.commit()` must be called. If it isn't — due to an exception or a forgotten call — nothing changes. The default is rollback, which is the safe path.

3. **Access all repositories through the UoW.** Never instantiate a repository directly. Always `uow.products.get()`, `uow.orders.add()`.

4. **Close the session in `__exit__`.** This prevents connection leaks, which are silent and deadly.

5. **One UoW per operation, no nesting.** Don't try to nest `with uow:` blocks. Each service function gets its own UoW instance.

6. **Collect and publish domain events after commit.** After `commit()`, iterate over all `.seen` aggregates in all repositories, pop their `.events`, and pass them to the message bus. This is the UoW-message-bus integration point (see `events-and-commands.md` for full details).

## Code Example

### Abstract Unit of Work

```python
import abc

class AbstractUnitOfWork(abc.ABC):
    products: AbstractProductRepository

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.rollback()

    def commit(self):
        self._commit()
        self.collect_new_events()

    def collect_new_events(self):
        for product in self.products.seen:
            while product.events:
                yield product.events.pop(0)

    @abc.abstractmethod
    def _commit(self):
        raise NotImplementedError

    @abc.abstractmethod
    def rollback(self):
        raise NotImplementedError
```

### SQLAlchemy Unit of Work

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

DEFAULT_SESSION_FACTORY = sessionmaker(
    bind=create_engine(config.get_postgres_uri())
)

class SqlAlchemyUnitOfWork(AbstractUnitOfWork):
    def __init__(self, session_factory=DEFAULT_SESSION_FACTORY):
        self.session_factory = session_factory

    def __enter__(self):
        self.session = self.session_factory()
        self.products = SqlAlchemyProductRepository(self.session)
        return super().__enter__()

    def __exit__(self, *args):
        super().__exit__(*args)
        self.session.close()

    def _commit(self):
        self.session.commit()

    def rollback(self):
        self.session.rollback()
```

### Service Layer Usage

```python
def create_product(sku: str, name: str, price: int, currency: str,
                   uow: AbstractUnitOfWork):
    with uow:
        product = model.Product(sku, name, model.Money(price, currency))
        uow.products.add(product)
        uow.commit()
```

The pattern is always: open `with uow:`, do work through repos, call `uow.commit()`.

### Fake Unit of Work for Testing

```python
class FakeUnitOfWork(AbstractUnitOfWork):
    def __init__(self):
        self.products = FakeProductRepository([])
        self.committed = False

    def _commit(self):
        self.committed = True

    def rollback(self):
        pass
```

The key insight: "We're faking out code that we wrote rather than third-party code." This is why the fake is simple — because the abstraction is simple.

## Common Mistakes

- **Auto-commit on context manager exit.** The UoW should rollback by default in `__exit__`, never auto-commit. If you forget to call `commit()`, nothing should change.
- **Forgetting to close the session.** Always `self.session.close()` in `__exit__()`. Connection pool exhaustion is hard to diagnose in production.
- **Multiple UoWs sharing a session.** Each UoW creates its own session. Don't pass sessions around.
- **Nested `with uow:` blocks.** If you think you need nesting, rethink your service function boundaries.
- **Not collecting events from `.seen` aggregates.** After commit, the UoW should collect events from all aggregates that were loaded or added during the transaction.

## Testing

Test that service functions commit when they should and rollback when they shouldn't:

```python
def test_create_product_commits(fake_uow):
    handlers.create_product("SKU-001", "Widget", 100, "USD", fake_uow)
    assert fake_uow.committed

def test_create_product_rolls_back_on_error(fake_uow):
    with pytest.raises(InvalidSku):
        handlers.create_product("", "Widget", 100, "USD", fake_uow)
    assert not fake_uow.committed
```
