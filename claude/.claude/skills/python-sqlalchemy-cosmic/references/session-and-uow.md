# Session and Unit of Work

## When to Use

You're setting up SQLAlchemy sessions to work with the Cosmic Python Unit of Work pattern. The UoW owns the session lifecycle — creating it on `__enter__`, committing/rolling back, and closing on `__exit__`.

## The Pattern

```python
# adapters/orm.py or config.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

DEFAULT_SESSION_FACTORY = sessionmaker(
    bind=create_engine("postgresql://user:pass@localhost/db"),
    expire_on_commit=False,  # CRITICAL for Cosmic Python
)
```

```python
# service_layer/unit_of_work.py
import abc
from adapters import repository

class AbstractUnitOfWork(abc.ABC):
    products: repository.AbstractProductRepository
    orders: repository.AbstractOrderRepository

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.rollback()

    @abc.abstractmethod
    def commit(self):
        raise NotImplementedError

    @abc.abstractmethod
    def rollback(self):
        raise NotImplementedError


class SqlAlchemyUnitOfWork(AbstractUnitOfWork):
    def __init__(self, session_factory=DEFAULT_SESSION_FACTORY):
        self.session_factory = session_factory

    def __enter__(self):
        self.session = self.session_factory()
        self.products = repository.SqlAlchemyProductRepository(self.session)
        self.orders = repository.SqlAlchemyOrderRepository(self.session)
        return super().__enter__()

    def __exit__(self, *args):
        super().__exit__(*args)
        self.session.close()

    def commit(self):
        self.session.commit()

    def rollback(self):
        self.session.rollback()
```

## Critical: `expire_on_commit=False`

By default, `session.commit()` **expires all loaded objects**. Any attribute access after commit triggers a new SQL query (or raises `DetachedInstanceError` if the session is closed).

In Cosmic Python, after committing you often need to:
- Access domain object attributes to return values
- Collect domain events from aggregates
- Log or report on what was committed

Set `expire_on_commit=False` to prevent this:

```python
# WRONG — attributes expire after commit
factory = sessionmaker(bind=engine)
session = factory()
session.add(product)
session.commit()
print(product.sku)  # Triggers new SQL query! Or raises DetachedInstanceError

# CORRECT — attributes stay accessible
factory = sessionmaker(bind=engine, expire_on_commit=False)
session = factory()
session.add(product)
session.commit()
print(product.sku)  # Works fine, uses cached value
```

## Session Lifecycle Rules

1. **One session per UoW instance.** Created in `__enter__`, closed in `__exit__`. Never shared across UoW instances.

2. **Session is NOT thread-safe.** Each thread/request/async task needs its own session. In threaded apps, create a new UoW per request.

3. **Session is NOT a cache.** Even with objects in the identity map, `select()` queries still hit the database. Only `session.get(Model, pk)` checks the identity map first.

4. **After rollback, objects are expired.** Pending (newly added) objects are expunged. The session is usable but all attribute access triggers fresh queries.

5. **After close, the session resets.** It can technically be reused, but in UoW pattern you create a new one each time.

6. **Transactions autobegin.** In 2.0, the first database operation implicitly starts a transaction. `commit()` or `rollback()` ends it. No need to call `session.begin()` explicitly.

## Connection Pooling

The `create_engine()` call configures the connection pool. Key settings:

```python
engine = create_engine(
    "postgresql://user:pass@localhost/db",
    pool_size=5,           # Max persistent connections (default: 5)
    max_overflow=10,       # Extra connections when pool is full (default: 10)
    pool_timeout=30,       # Seconds to wait for a connection (default: 30)
    pool_recycle=1800,     # Recycle connections after N seconds (default: -1/never)
    pool_pre_ping=True,    # Test connections before use (recommended for production)
    echo=False,            # Set True for SQL logging during development
)
```

For production, always set `pool_pre_ping=True` to detect stale connections (especially important with PostgreSQL behind a load balancer or firewall that drops idle connections).

## Scoped Sessions (Web Applications)

For web frameworks where you want one session per request without passing it manually:

```python
from sqlalchemy.orm import scoped_session

session_factory = sessionmaker(bind=engine, expire_on_commit=False)
ScopedSession = scoped_session(session_factory)

# In request middleware:
@app.teardown_request
def cleanup(exception=None):
    ScopedSession.remove()  # Returns connection to pool
```

However, in Cosmic Python the UoW pattern makes scoped sessions unnecessary — the UoW manages session lifecycle explicitly.

## Common Mistakes

- **Forgetting `expire_on_commit=False`.** The #1 source of mysterious `DetachedInstanceError` in Cosmic Python apps.
- **Sharing a session across threads.** Each thread needs its own session. The UoW creates a fresh one on each `__enter__`.
- **Not closing sessions.** Always `session.close()` in `__exit__()`. Connection pool exhaustion is silent until production.
- **Calling `session.begin()` explicitly.** In 2.0, transactions autobegin. Calling `begin()` on an already-begun session raises `InvalidRequestError`.
- **Using `autocommit=True`.** Removed in 2.0. Use explicit `commit()`.

## Testing

```python
@pytest.fixture
def session_factory():
    engine = create_engine("sqlite:///:memory:")
    metadata.create_all(engine)
    start_mappers()
    yield sessionmaker(bind=engine, expire_on_commit=False)
    clear_mappers()

@pytest.fixture
def uow(session_factory):
    return SqlAlchemyUnitOfWork(session_factory)

def test_uow_commits(uow):
    with uow:
        product = Product("SKU-001", "Widget", Money(100, "USD"))
        uow.products.add(product)
        uow.commit()
    # Verify in a new session
    with uow:
        loaded = uow.products.get("SKU-001")
        assert loaded.name == "Widget"
```
