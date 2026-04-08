# Hexagonal Architecture Mapping

## When to Use

You're working with a team that uses hexagonal architecture (ports and adapters) terminology, or you're reading hexagonal architecture resources and want to map the concepts to the Cosmic Python patterns you already know.

## The Key Insight

Cosmic Python IS hexagonal architecture. The book implements ports and adapters throughout — it just uses DDD vocabulary instead of hexagonal vocabulary. The patterns are the same; the names differ.

## Terminology Mapping

| Hexagonal Architecture | Cosmic Python | Example |
|---|---|---|
| **Driving port** (primary) | Abstract service interface | `AbstractUnitOfWork`, handler function signatures |
| **Driven port** (secondary) | Abstract base class | `AbstractRepository` |
| **Driving adapter** (primary) | Entrypoint | Flask route, CLI command, message consumer |
| **Driven adapter** (secondary) | Concrete implementation | `SqlAlchemyRepository`, `FakeRepository` |
| **Application service** | Service layer handler | `handlers.create_order()` |
| **Domain model** | Domain model | Entities, Value Objects, Domain Services |
| **DI container / Composition root** | Bootstrap script | `bootstrap.py` |

## Driving vs Driven

The hexagonal distinction that Cosmic Python doesn't name explicitly:

### Driving (Primary) — Outside → Application

The outside world calls into your application. These adapters translate external requests into commands/calls.

```
HTTP Request  →  Flask Route (driving adapter)  →  Service Handler
CLI Command   →  Click Command (driving adapter) →  Service Handler
Message Queue →  Consumer (driving adapter)      →  Service Handler
```

In Cosmic Python, these live in `entrypoints/`. They're thin wrappers that parse input, call a service function, and translate the response.

### Driven (Secondary) — Application → Outside

Your application calls out to external systems. These adapters implement interfaces defined by the application.

```
Service Handler  →  AbstractRepository (port)  →  SqlAlchemyRepository (driven adapter)
Service Handler  →  send_mail (port)           →  SMTPEmailSender (driven adapter)
Service Handler  →  publish (port)             →  RedisPublisher (driven adapter)
```

In Cosmic Python, these live in `adapters/`. The abstract base classes are the ports; the concrete implementations are the adapters.

## Directory Structure Comparison

### Cosmic Python Style

```
src/
├── domain/              # Domain model
├── service_layer/       # Application services (use cases)
│   ├── handlers.py
│   └── unit_of_work.py
├── adapters/            # Driven adapters (secondary)
│   ├── orm.py
│   └── repository.py
├── entrypoints/         # Driving adapters (primary)
│   └── flask_app.py
└── bootstrap.py         # Composition root
```

### Hexagonal Style (Szymon Miks)

```
module/
├── domain/              # Domain model
├── application/         # Use cases + DTOs
│   ├── commands.py
│   ├── queries.py
│   └── ports/           # Port interfaces (both driving and driven)
├── infrastructure/      # Driven adapters
│   ├── persistence/
│   └── external_services/
├── controllers.py       # Driving adapters (REST)
└── bootstrap.py         # DI container
```

### Key Differences

| Aspect | Cosmic Python | Hexagonal |
|---|---|---|
| Port location | Scattered (ABC in each module) | Grouped in `application/ports/` |
| Adapter grouping | By concern (`adapters/`, `entrypoints/`) | By direction (driving vs driven) |
| Use case naming | "Handler" | "Command handler" / "Query handler" |
| DI approach | `functools.partial` in bootstrap | Container or manual wiring |

The differences are organizational, not architectural. The dependency direction is identical: everything points inward toward the domain.

## When Hexagonal Terminology Helps

1. **Onboarding** — "This is a driving adapter" is clearer than "this is an entrypoint" for developers familiar with hexagonal architecture.
2. **Port discovery** — Grouping all port interfaces in one `ports/` directory makes it easier to see what the application can do and what it depends on.
3. **Testing strategy** — "Mock the driven ports, test through the driving ports" is a clean mental model for deciding what to fake.

## When Cosmic Python Terminology Is Better

1. **Pattern specificity** — "Repository" and "Unit of Work" are more specific than "driven adapter." They tell you not just the direction but the exact pattern.
2. **Incremental adoption** — Cosmic Python's pattern-by-pattern approach (add Repository, then UoW, then events) is more practical than "adopt hexagonal architecture."
3. **Python idioms** — Abstract base classes as ports, `with` statement for UoW, dataclasses for events — these are Pythonic implementations that hexagonal literature (often Java-oriented) doesn't cover.

## Reference Implementation

[Szymon Miks' hexagonal architecture example](https://github.com/szymon6927/hexagonal-architecture-python) — FastAPI + MongoDB gym management system with full port/adapter separation. Good for seeing the hexagonal directory structure in a real Python project.
