# Getting Started

## When to Use

You're starting a new Python project that has meaningful domain logic — business rules that go beyond simple CRUD. You want clean separation of concerns, fast tests, and an architecture that can evolve.

## When NOT to Use

Simple CRUD apps, scripts, data pipelines, or prototypes where speed matters more than structure. Use Django models or SQLAlchemy declarative directly — you can always adopt these patterns later.

## Setup Steps

### 1. Create the directory structure

```
src/
├── domain/
│   └── model.py
├── service_layer/
│   ├── handlers.py
│   └── unit_of_work.py
├── adapters/
│   ├── orm.py
│   └── repository.py
├── entrypoints/
│   └── flask_app.py
└── bootstrap.py
tests/
├── unit/
│   ├── test_model.py
│   └── test_handlers.py
├── integration/
│   └── test_repository.py
└── e2e/
    └── test_api.py
```

### 2. Start with the domain model

Write your business rules as plain Python classes. No imports from infrastructure packages. This is where you spend most of your design thinking.

```python
# domain/model.py
from dataclasses import dataclass

@dataclass(frozen=True)
class Money:
    """Value Object — identified by its data, immutable."""
    amount: int
    currency: str

class Product:
    """Entity — identified by its sku, mutable."""
    def __init__(self, sku: str, name: str, price: Money):
        self.sku = sku
        self.name = name
        self.price = price
        self.events: list = []

    def __eq__(self, other):
        if not isinstance(other, Product):
            return NotImplemented
        return self.sku == other.sku

    def __hash__(self):
        return hash(self.sku)
```

### 3. Write domain tests first

Test business behavior in domain language. No infrastructure, no fakes needed.

```python
# tests/unit/test_model.py
def test_money_equality():
    assert Money(100, "USD") == Money(100, "USD")
    assert Money(100, "USD") != Money(200, "USD")

def test_product_identity():
    p1 = Product("SKU-001", "Widget", Money(100, "USD"))
    p2 = Product("SKU-001", "Updated Widget", Money(200, "USD"))
    assert p1 == p2  # Same identity (sku), different data
```

### 4. Add the repository and ORM

Map domain classes to database tables imperatively — the ORM depends on the model, not the reverse.

```python
# adapters/orm.py
from sqlalchemy import Table, Column, String, Integer, MetaData
from sqlalchemy.orm import registry

mapper_registry = registry()
metadata = mapper_registry.metadata

products = Table(
    "products", metadata,
    Column("sku", String(255), primary_key=True),
    Column("name", String(255)),
    Column("price_amount", Integer),
    Column("price_currency", String(3)),
)

def start_mappers():
    mapper_registry.map_imperatively(Product, products)
```

### 5. Add the service layer with Unit of Work

One function per use case. Accept primitives, delegate to the domain, commit through UoW.

```python
# service_layer/handlers.py
from domain import model

def create_product(sku: str, name: str, price: int, currency: str,
                   uow: AbstractUnitOfWork):
    with uow:
        product = model.Product(sku, name, model.Money(price, currency))
        uow.products.add(product)
        uow.commit()
```

### 6. Add a thin entrypoint

The API layer parses HTTP, calls the service function, and translates exceptions to status codes. Nothing else.

```python
# entrypoints/flask_app.py
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route("/products", methods=["POST"])
def create_product_endpoint():
    bus = bootstrap.bootstrap()
    try:
        handlers.create_product(**request.json, uow=bus.uow)
        return "OK", 201
    except model.InvalidSku as e:
        return jsonify({"error": str(e)}), 400
```

### 7. Wire it together with bootstrap

```python
# bootstrap.py
from adapters import orm
from service_layer import unit_of_work

def bootstrap(start_orm: bool = True,
              uow=None) -> dict:
    if start_orm:
        orm.start_mappers()
    if uow is None:
        uow = unit_of_work.SqlAlchemyUnitOfWork()
    return {"uow": uow}
```

## Walking Skeleton Approach

Don't try to implement everything at once. Handle one use case end-to-end first:

1. Domain model for one entity
2. Repository + ORM mapping for that entity
3. One service function using UoW
4. One API endpoint calling that service
5. Tests at each layer

This "walking skeleton" forces you to answer infrastructure questions (database, testing setup, config) early, before you're deep in complex business logic.

## Common Mistakes

- **Over-engineering from the start.** Don't add events, CQRS, or aggregates until you need them. Start with domain model + repository + service layer + UoW.
- **Putting business logic in the service layer.** If your service function has `if/else` branches that make business decisions, those belong in the domain model.
- **Importing infrastructure in the domain.** Even "just this one ORM import" breaks the architecture. The domain model must be pure Python.
- **Writing too many E2E tests.** Start with one happy path E2E test. Push everything else down to service-layer tests with FakeUnitOfWork.
