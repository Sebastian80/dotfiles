# Events and Commands

## When to Use

You have "when X happens, do Y" logic in your system. Or you need to decouple actions from their side effects. Or you need to modify multiple aggregates in response to a single user action (one aggregate per transaction — events bridge the gap).

## When NOT to Use

If every use case is a simple request-response with no side effects and no cross-aggregate communication, a message bus adds infrastructure without benefit.

## The Fundamental Distinction

| | Commands | Events |
|---|---|---|
| **Naming** | Imperative: `CreateOrder`, `ShipOrder` | Past tense: `OrderCreated`, `OrderShipped` |
| **Intent** | "Do this thing" | "This thing happened" |
| **Handler count** | Exactly ONE | Zero or more |
| **On failure** | Exception bubbles up, operation fails | Log error, continue processing other handlers |
| **Sender knows** | Which handler will execute | Nothing about who's listening |

Commands express intent. Events record facts. Keep this distinction sharp.

## Implementation Rules

1. **Events and commands are immutable dataclasses.** Data only, no behavior.

2. **Domain model appends events to a `.events` list.** It never calls infrastructure directly — no sending emails, no publishing to queues, no HTTP calls from domain code.

3. **Stop using exceptions for expected domain states.** If "out of stock" is a normal business scenario, emit an `OutOfStock` event instead of raising an exception. Reserve exceptions for truly exceptional conditions.

4. **Commands modify a single aggregate.** If you need to update another aggregate, the handler emits an event, and a separate event handler issues a new command for that aggregate.

5. **Event handler failures must not break command processing.** If `send_notification(OrderShipped)` fails, the order was still shipped. Log the error, retry later.

6. **Handlers must be idempotent.** Messages can be delivered more than once. Every handler must produce the same result whether called once or three times.

## Code Example

### Event and Command Definitions

```python
# domain/events.py
from dataclasses import dataclass

class Event:
    pass

@dataclass
class OrderCreated(Event):
    order_id: str
    customer_id: str

@dataclass
class OrderShipped(Event):
    order_id: str

@dataclass
class OutOfStock(Event):
    sku: str


# domain/commands.py
from dataclasses import dataclass

class Command:
    pass

@dataclass
class CreateOrder(Command):
    customer_id: str
    items: list[dict]

@dataclass
class ShipOrder(Command):
    order_id: str
```

### Domain Model Records Events

```python
class Order:
    def __init__(self, order_id: str, customer_id: str):
        self.order_id = order_id
        self.customer_id = customer_id
        self.events: list = []

    @classmethod
    def create(cls, customer_id: str) -> "Order":
        order = cls(order_id=generate_id(), customer_id=customer_id)
        order.events.append(OrderCreated(order.order_id, customer_id))
        return order

    def ship(self):
        if self.status != OrderStatus.PAID:
            raise CannotShip("Order must be paid")
        self.status = OrderStatus.SHIPPED
        self.events.append(OrderShipped(self.order_id))
```

### Message Bus

```python
# service_layer/messagebus.py
from typing import Callable, Type

class MessageBus:
    def __init__(self, uow, event_handlers, command_handlers):
        self.uow = uow
        self.event_handlers = event_handlers
        self.command_handlers = command_handlers

    def handle(self, message):
        queue = [message]
        while queue:
            message = queue.pop(0)
            if isinstance(message, events.Event):
                self._handle_event(message, queue)
            elif isinstance(message, commands.Command):
                self._handle_command(message, queue)

    def _handle_command(self, command, queue):
        handler = self.command_handlers[type(command)]
        result = handler(command)
        queue.extend(self.uow.collect_new_events())

    def _handle_event(self, event, queue):
        for handler in self.event_handlers.get(type(event), []):
            try:
                handler(event)
                queue.extend(self.uow.collect_new_events())
            except Exception:
                logger.exception("Error handling event %s", event)
                continue  # Don't break — process remaining handlers
```

### Handler Registration

```python
# service_layer/handlers.py

# Commands: exactly one handler each
COMMAND_HANDLERS: dict[Type[commands.Command], Callable] = {
    commands.CreateOrder: create_order,
    commands.ShipOrder: ship_order,
}

# Events: zero or more handlers each
EVENT_HANDLERS: dict[Type[events.Event], list[Callable]] = {
    events.OrderCreated: [send_confirmation_email, update_analytics],
    events.OrderShipped: [send_shipping_notification, update_inventory],
    events.OutOfStock: [notify_purchasing_team],
}
```

## UoW-Message-Bus Integration

This is the key integration point. After each handler runs, the message bus collects new events from aggregates that were loaded during the transaction:

1. Repository tracks `.seen` aggregates (objects loaded or added)
2. After `commit()`, the UoW iterates over `.seen` aggregates
3. For each aggregate, it pops events from `.events`
4. Those events go back into the message bus queue

This is why the bus processes a queue, not a single message — each handler can produce new events.

```python
# In AbstractUnitOfWork
def collect_new_events(self):
    for product in self.products.seen:
        while product.events:
            yield product.events.pop(0)
```

## Error Handling Strategy

- **Command handler fails:** Exception propagates to the caller. The transaction rolls back. The user sees an error.
- **Event handler fails:** Log the exception. Continue processing other handlers for the same event, and other events in the queue. The command that triggered the event already succeeded.
- **Retry strategy:** For transient failures (network issues, temporary unavailability), implement retry with exponential backoff. For permanent failures (invalid data), log and alert.

## Common Mistakes

- **Raising exceptions AND publishing events for the same scenario.** Pick one. If "out of stock" is an event, don't also raise `OutOfStock` as an exception.
- **Handlers that fail silently.** Always log event handler failures. Silent failures are invisible bugs.
- **Circular handler dependencies.** Event A triggers handler that emits Event B, which triggers handler that emits Event A. Guard against infinite loops.
- **Assuming synchronous event handling is fast.** If `send_email()` takes 2 seconds, every command that triggers that event blocks for 2 seconds. Consider async processing for slow handlers.
- **Calling service functions from other service functions.** Use the message bus: emit an event from one handler, let another handler respond. This keeps handlers decoupled.

## Testing

Test at three levels:

```python
# 1. Domain model produces correct events
def test_creating_order_emits_event():
    order = Order.create("CUST-001")
    assert order.events == [OrderCreated(order.order_id, "CUST-001")]

# 2. Handlers work correctly in isolation
def test_ship_order_handler():
    uow = FakeUnitOfWork()
    # ... set up order in PAID status
    handlers.ship_order(commands.ShipOrder("ORD-001"), uow=uow)
    assert uow.committed

# 3. Full message bus integration
def test_order_shipped_triggers_notification(fake_bus):
    fake_bus.handle(commands.CreateOrder("CUST-001", items=[...]))
    fake_bus.handle(commands.ShipOrder("ORD-001"))
    assert "ORD-001" in fake_bus.notifications_sent
```
