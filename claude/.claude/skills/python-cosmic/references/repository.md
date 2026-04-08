# Repository Pattern

## When to Use

You need to persist and retrieve domain objects while keeping the domain model free of database concerns. The repository pretends all your data is in memory — `add` to store, `get` to retrieve.

## When NOT to Use

Simple CRUD where the ORM model IS the domain model. If you're using Django's `Model.objects.filter()` and it's working fine, a repository adds complexity without benefit.

## Implementation Rules

1. **Keep the interface minimal.** `add()` and `get()` — that's it. Resist the urge to add `list()`, `find_by_x()`, `search()`. Each method you add is a method you must implement in every concrete repository AND every fake.

2. **ORM depends on model, never the reverse.** Domain classes have zero ORM imports. The ORM module maps domain classes to tables using imperative mapping.

3. **One repository per aggregate.** After you identify aggregates, each aggregate root gets its own repository. Repositories return aggregate roots, never internal entities.

4. **`.commit()` is NOT the repository's job.** The repository stores and retrieves. Transaction management belongs to the Unit of Work.

5. **Track seen objects.** The repository should track which objects it has loaded (via a `.seen` set) so the Unit of Work can collect domain events from them after commit.

## Code Example

### Abstract Repository

```python
import abc
from domain import model

class AbstractProductRepository(abc.ABC):
    def __init__(self):
        self.seen: set[model.Product] = set()

    def add(self, product: model.Product):
        self._add(product)
        self.seen.add(product)

    def get(self, sku: str) -> model.Product:
        product = self._get(sku)
        if product:
            self.seen.add(product)
        return product

    @abc.abstractmethod
    def _add(self, product: model.Product):
        raise NotImplementedError

    @abc.abstractmethod
    def _get(self, sku: str) -> model.Product:
        raise NotImplementedError
```

### SQLAlchemy Repository

```python
from sqlalchemy.orm import Session

class SqlAlchemyProductRepository(AbstractProductRepository):
    def __init__(self, session: Session):
        super().__init__()
        self.session = session

    def _add(self, product: model.Product):
        self.session.add(product)

    def _get(self, sku: str) -> model.Product:
        return self.session.query(model.Product).filter_by(sku=sku).first()
```

### Imperative ORM Mapping (SQLAlchemy 2.x)

The ORM imports the model and maps it to tables. The model never knows about SQLAlchemy.

```python
# adapters/orm.py
from sqlalchemy import Table, Column, String, Integer, ForeignKey, MetaData
from sqlalchemy.orm import registry, relationship
from domain.model import Product, LineItem

mapper_registry = registry()
metadata = mapper_registry.metadata

products = Table(
    "products", metadata,
    Column("sku", String(255), primary_key=True),
    Column("name", String(255)),
    Column("price_amount", Integer),
    Column("price_currency", String(3)),
)

line_items = Table(
    "line_items", metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("order_id", String(255)),
    Column("sku", String(255)),
    Column("qty", Integer),
)

def start_mappers():
    mapper_registry.map_imperatively(LineItem, line_items)
    mapper_registry.map_imperatively(Product, products, properties={
        "line_items": relationship(LineItem),
    })
```

### Fake Repository for Testing

```python
class FakeProductRepository(AbstractProductRepository):
    def __init__(self, products=None):
        super().__init__()
        self._products = set(products or [])

    def _add(self, product: model.Product):
        self._products.add(product)

    def _get(self, sku: str) -> model.Product:
        return next((p for p in self._products if p.sku == sku), None)
```

The fake is backed by a `set()` — if it's hard to write a fake, the abstraction is too complex.

## Common Mistakes

- **Repository that calls `.commit()`.** Commits belong to the Unit of Work. The repository only calls `session.add()` and `session.query()`.
- **Returning ORM objects instead of domain objects.** If your repository returns objects with SQLAlchemy attributes attached, the mapping is wrong.
- **Too many query methods.** Every `find_by_x()` you add must be replicated in the fake. Keep it minimal and push complex queries to CQRS read models.
- **Forgetting `.seen` tracking.** Without tracking which objects were loaded, the Unit of Work can't collect domain events for publishing.

## Testing

**Integration tests** verify the real repository round-trips data correctly through the database:

```python
def test_repository_can_save_and_retrieve_product(session):
    product = Product("SKU-001", "Widget", Money(100, "USD"))
    repo = SqlAlchemyProductRepository(session)
    repo.add(product)
    session.commit()

    retrieved = repo.get("SKU-001")
    assert retrieved == product
    assert retrieved.name == "Widget"
```

**Unit tests** at higher layers use `FakeRepository` — never hit the database.
