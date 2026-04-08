# Dependency Injection

## When to Use

You need to wire together handlers, repositories, UoW, and external services at application startup. You want to swap implementations for testing (real DB → fake, real email → stub).

## When NOT to Use

If your app has one handler with one dependency, just pass it directly. DI infrastructure pays off when you have many handlers with shared dependencies.

## Implementation Rules

1. **Bootstrap script wires everything once at startup.** Don't scatter dependency creation across the codebase. One place, one time.

2. **Use `functools.partial` for injection.** It's simple, explicit, and doesn't require a framework.

3. **Initialize once, reuse.** Call `bootstrap()` once when the app starts. Reuse the returned message bus instance for all requests.

4. **No DI framework needed for most projects.** Manual DI with a bootstrap function is clearer and has fewer surprises than a framework.

5. **The message bus is NOT thread-safe by default.** For threaded apps (gunicorn with threads, Django), use thread-local storage or create a new UoW per request.

## Code Example

### Bootstrap Script

```python
# bootstrap.py
import functools
from adapters import orm, email
from adapters.repository import SqlAlchemyProductRepository
from service_layer import handlers, messagebus, unit_of_work

def bootstrap(
    start_orm: bool = True,
    uow: unit_of_work.AbstractUnitOfWork = None,
    send_mail: callable = None,
    publish: callable = None,
) -> messagebus.MessageBus:
    if start_orm:
        orm.start_mappers()
    if uow is None:
        uow = unit_of_work.SqlAlchemyUnitOfWork()
    if send_mail is None:
        send_mail = email.send
    if publish is None:
        publish = redis_publisher.publish

    dependencies = {
        "uow": uow,
        "send_mail": send_mail,
        "publish": publish,
    }

    # Inject dependencies into handlers using functools.partial
    injected_command_handlers = {
        command_type: _inject(handler, dependencies)
        for command_type, handler in handlers.COMMAND_HANDLERS.items()
    }
    injected_event_handlers = {
        event_type: [_inject(h, dependencies) for h in event_handlers]
        for event_type, event_handlers in handlers.EVENT_HANDLERS.items()
    }

    return messagebus.MessageBus(
        uow=uow,
        command_handlers=injected_command_handlers,
        event_handlers=injected_event_handlers,
    )


def _inject(handler, dependencies):
    """Bind matching dependencies to handler parameters."""
    import inspect
    params = inspect.signature(handler).parameters
    deps = {
        name: dep for name, dep in dependencies.items()
        if name in params
    }
    return functools.partial(handler, **deps)
```

### How `functools.partial` Works Here

```python
# Handler declares its dependencies as parameters
def create_order(cmd: commands.CreateOrder,
                 uow: AbstractUnitOfWork,
                 send_mail: callable):
    with uow:
        order = Order.create(cmd.customer_id)
        uow.orders.add(order)
        uow.commit()
    send_mail(to=cmd.customer_id, subject="Order confirmed")

# Bootstrap binds the dependencies
create_order_composed = functools.partial(
    create_order,
    uow=SqlAlchemyUnitOfWork(),
    send_mail=email.send,
)

# At runtime, the message bus calls with only the command
create_order_composed(cmd)
# Equivalent to: create_order(cmd, uow=real_uow, send_mail=real_email)
```

### Entrypoint Usage

```python
# entrypoints/flask_app.py
from bootstrap import bootstrap

app = Flask(__name__)
bus = bootstrap()  # Initialize ONCE

@app.route("/orders", methods=["POST"])
def create_order_endpoint():
    cmd = commands.CreateOrder(**request.json)
    bus.handle(cmd)
    return "OK", 201
```

### Test Overrides

```python
# Unit tests — everything fake, no ORM
def test_create_order():
    bus = bootstrap(
        start_orm=False,
        uow=FakeUnitOfWork(),
        send_mail=lambda **kwargs: None,
        publish=lambda *args: None,
    )
    bus.handle(commands.CreateOrder(
        customer_id="CUST-001",
        items=[{"sku": "SKU-001", "qty": 1}],
    ))
    # assert on FakeUnitOfWork state

# Integration tests — real DB (SQLite in-memory), fake I/O
@pytest.fixture
def bus(sqlite_session_factory):
    return bootstrap(
        start_orm=True,
        uow=unit_of_work.SqlAlchemyUnitOfWork(sqlite_session_factory),
        send_mail=lambda **kwargs: None,
        publish=lambda *args: None,
    )
```

The pattern: production gets real everything. Integration tests get real DB + fake I/O. Unit tests get all fakes.

## Common Mistakes

- **Calling `bootstrap()` on every request.** Initialize once at startup, reuse the bus. Creating a new ORM mapping per request causes errors.
- **Hardcoding concrete dependencies in handlers.** `from adapters.email import send` inside a handler makes it untestable. Accept dependencies as parameters.
- **Using a DI framework when you have 5 handlers.** Manual DI with `functools.partial` is simpler and more debuggable. Consider a framework only when you have deep dependency chains.
- **Thread-safety assumptions.** The UoW holds a database session. Sharing one UoW across threads leads to session conflicts. Create per-request UoWs in threaded apps.

## Testing

The bootstrap function itself should be tested to verify wiring works:

```python
def test_bootstrap_returns_configured_bus():
    bus = bootstrap(start_orm=False, uow=FakeUnitOfWork())
    assert isinstance(bus, messagebus.MessageBus)
    assert commands.CreateOrder in bus.command_handlers
```
