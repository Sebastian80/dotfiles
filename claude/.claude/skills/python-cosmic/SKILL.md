---
name: python-cosmic
description: "Architecture Patterns with Python — guides domain modeling, pattern selection, and implementation following Cosmic Python (DDD, Repository, Service Layer, Unit of Work, Aggregates, Events, CQRS, DI). Also covers hexagonal architecture (ports and adapters) mapping. Use when designing or building Python applications with domain logic, structuring a Python project with clean architecture, deciding which architectural pattern fits a use case, or mapping between hexagonal and DDD terminology. Invoke with /python-cosmic."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash
  - Agent
---

# Cosmic Python: Architecture Patterns with Python

Based on [Architecture Patterns with Python](https://www.cosmicpython.com/book/) by Harry Percival & Bob Gregory.

## The One Rule

Dependency direction always points inward toward the domain model. If you violate this, the entire architecture collapses.

```
Entrypoints (Flask, FastAPI, CLI, etc.)
    → Service Layer (use case orchestration)
        → Domain Model (business rules, entities, value objects)
            → NOTHING (zero infrastructure imports)

Adapters (Repository, ORM, Email, Message Queue)
    → Domain Model (via abstract interfaces)
```

The domain model is the center. Everything depends on it. It depends on nothing.

## When to Use These Patterns

**Worth it:** Complex domains where business rules matter, change independently of infrastructure, and need to evolve over time. Systems where you want fast, reliable tests.

**Not worth it:** Simple CRUD applications that are thin wrappers around a database. Scripts, data pipelines, CLI tools with no domain logic. The overhead isn't justified — use Django/SQLAlchemy models directly.

If you're unsure, start with a service layer (it's the lowest-cost entry point) and add patterns as complexity grows.

## How to Use This Skill

Assess what the user is working on and read the relevant reference files. Load the primary match plus up to 2 closely related files (max 3 total per invocation).

| What you're doing | Read this | Also load if relevant |
|---|---|---|
| Starting a new Python project with domain logic | `references/getting-started.md` | `references/domain-model.md` |
| Modeling business concepts (entities, value objects) | `references/domain-model.md` | — |
| Persisting or retrieving domain objects | `references/repository.md` | `references/unit-of-work.md` |
| Writing a use case or endpoint handler | `references/service-layer.md` | `references/unit-of-work.md` |
| Multiple objects must stay consistent together | `references/aggregates.md` | `references/events-and-commands.md` |
| Reacting to domain events ("when X happens, do Y") | `references/events-and-commands.md` | `references/aggregates.md` |
| Read performance problems or complex queries | `references/cqrs.md` | — |
| Wiring dependencies at application startup | `references/dependency-injection.md` | — |
| Retrofitting patterns into legacy Python code | `references/adoption-guide.md` | `references/service-layer.md` |
| Mapping to hexagonal architecture / ports and adapters | `references/hexagonal-mapping.md` | — |
| Writing or structuring tests | `references/testing-guide.md` | (the relevant layer's reference) |

After reading the relevant references, give actionable guidance for the specific situation. Don't dump pattern theory — guide the user through what they need to do right now.

## Universal Rules

These apply regardless of which pattern you're working with:

1. **Domain model has zero infrastructure imports.** No SQLAlchemy, no Flask, no Django, no requests. Plain Python only.
2. **One aggregate modified per transaction.** Cross-aggregate changes happen via domain events, not by modifying two aggregates in the same service call.
3. **Commands have exactly one handler; events have zero or more.** Commands fail loudly; event handler failures are logged and processing continues.
4. **Service layer orchestrates, never contains business logic.** If you see sorting, filtering, or business decisions in a service function, push them into the domain model.
5. **Handlers must be idempotent.** Every handler must be safe to retry — messages can and will be delivered more than once.
6. **ORM depends on model, never the reverse.** Use imperative mapping (`registry.map_imperatively()` in SQLAlchemy 2.x) so domain classes stay free of ORM imports.
7. **Explicit commit; default is rollback.** If `uow.commit()` isn't called, nothing changes. This makes the "do nothing" path safe.
8. **Access repositories only through Unit of Work.** Never instantiate a repository directly — always go through `uow.products`, `uow.orders`, etc.

## Directory Structure

The canonical project layout separates concerns by architectural layer:

```
src/
├── domain/              # Business rules — depends on NOTHING
│   ├── model.py         # Entities, Value Objects, Domain Services
│   ├── events.py        # Domain event dataclasses
│   └── commands.py      # Command dataclasses
├── service_layer/       # Use case orchestration — depends on domain
│   ├── handlers.py      # Command and event handlers
│   ├── unit_of_work.py  # Abstract UoW + concrete implementation
│   └── messagebus.py    # Routes commands/events to handlers
├── adapters/            # Infrastructure — depends on domain
│   ├── orm.py           # SQLAlchemy table definitions + imperative mapping
│   └── repository.py    # Abstract repo + SQLAlchemy implementation
├── entrypoints/         # HTTP/CLI — depends on service layer
│   ├── flask_app.py     # (or fastapi_app.py) Thin HTTP wrapper
│   └── cli.py           # CLI commands
└── bootstrap.py         # Wires all dependencies at startup
```

Adapt this to your project's needs — the exact filenames matter less than the dependency direction between layers.
