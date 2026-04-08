---
name: python-sqlalchemy-cosmic
description: "SQLAlchemy 2.0 for Cosmic Python architecture — imperative mapping, session lifecycle in Unit of Work, repository queries with select(), relationship configuration, and 1.x→2.0 migration. Use when writing SQLAlchemy code in a Cosmic Python project, setting up imperative ORM mapping, configuring SQLAlchemy sessions for Unit of Work, writing repository queries, or migrating SQLAlchemy 1.x patterns to 2.0. Invoke with /python-sqlalchemy-cosmic."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash
  - Agent
---

# SQLAlchemy 2.0 for Cosmic Python

How to use SQLAlchemy 2.0 correctly within a Cosmic Python architecture. All examples use imperative mapping to keep domain models free of ORM imports.

## Golden Rules

1. **Domain model has zero SQLAlchemy imports.** Not even `Column` or `relationship`. All ORM configuration lives in `adapters/orm.py`.
2. **Use `registry.map_imperatively()`**, not declarative base. This is what keeps domain classes clean.
3. **Use `select()` + `session.scalars()`**, not `session.query()`. The `Query` API is legacy and receives no new features.
4. **Set `expire_on_commit=False`** on sessionmaker. Without this, accessing domain object attributes after `uow.commit()` triggers unexpected SQL queries.
5. **Use `back_populates`**, not `backref`. Explicit is better than implicit — define both sides.
6. **Use `selectinload()` for collections, `joinedload()` for scalars.** Prevent N+1 queries in repository methods.
7. **`joinedload()` on collections requires `.unique()`** on results. Forgetting this is the #1 SQLAlchemy 2.0 migration pitfall.
8. **Call `start_mappers()` exactly once** at application startup (via bootstrap). Calling it twice raises errors.

## Decision Tree

Assess what you're doing and read the relevant reference file. Load max 2 files per invocation.

| What you're doing | Read this | Also load if relevant |
|---|---|---|
| Mapping domain classes to database tables | `references/imperative-mapping.md` | `references/relationships.md` |
| Configuring relationships between entities | `references/relationships.md` | `references/imperative-mapping.md` |
| Setting up Unit of Work with SQLAlchemy sessions | `references/session-and-uow.md` | — |
| Writing repository queries (CRUD, filtering, joins) | `references/querying.md` | — |
| Fixing deprecated 1.x patterns or migrating to 2.0 | `references/migration-from-1x.md` | (the relevant topic's reference) |
| Building CQRS read models (Core SQL, denormalized tables) | `references/cqrs-read-side.md` | — |
| Setting up Alembic migrations with imperative mapping | `references/alembic.md` | — |
| Setting up test fixtures for SQLAlchemy | `references/testing.md` | — |

## Quick Reference: What Changed in 2.0

| 1.x (deprecated) | 2.0 (use this) |
|---|---|
| `session.query(Model).filter_by(...)` | `session.scalars(select(Model).filter_by(...))` |
| `session.query(Model).get(pk)` | `session.get(Model, pk)` |
| `mapper(Model, table)` | `registry.map_imperatively(Model, table)` |
| `backref="name"` | `back_populates="name"` (on both sides) |
| `MetaData(bind=engine)` | `metadata.create_all(engine)` |
| `engine.execute(text)` | `with engine.connect() as conn: conn.execute(text(...))` |
| `relationship(lazy="dynamic")` | `relationship(lazy="write_only")` |
