---
name: python-sqlalchemy-core
description: "SQLAlchemy 2.0 Core reference — Engine, Connection, SQL Expression Language, schema definition, column types, DML operations, and transactions. Use when working with SQLAlchemy Core (not ORM), writing raw SQL expressions, defining table schemas, managing database connections/pools, performing bulk data operations, or needing the SQL Expression Language. Invoke with /python-sqlalchemy-core."
allowed-tools:
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  - Bash
  - Agent
---

# SQLAlchemy 2.0 Core

The SQL Expression Language, schema definition, and connection management layer of SQLAlchemy. Use Core when you don't need ORM features (identity map, relationship loading, change tracking) — for CQRS read models, data pipelines, bulk operations, or when you want type-safe SQL without ORM overhead.

## Golden Rules

1. **Always use context managers for connections.** `with engine.connect() as conn:` — never leave connections open.
2. **Always use `text()` for raw SQL strings.** Bare strings are rejected in 2.0.
3. **Always call `conn.commit()` explicitly.** "Commit as you go" is the 2.0 default — no autocommit.
4. **Use `select()`, `insert()`, `update()`, `delete()` from `sqlalchemy`.** Not from `sqlalchemy.sql` or other submodules.
5. **`select()` takes positional args.** `select(users.c.name, users.c.email)` — not a list.
6. **Use `conn.execute()` for Core, `session.execute()` for ORM.** Don't mix them.
7. **Use `pool_pre_ping=True` in production** to detect stale connections.

## Decision Tree

| What you're doing | Read this |
|---|---|
| Creating an engine, connection URLs, pooling | `references/engine-and-connections.md` |
| Defining tables, columns, constraints, indexes | `references/schema.md` |
| Choosing column types, custom types | `references/types.md` |
| Writing SELECT queries (filter, join, group, subquery) | `references/select-queries.md` |
| INSERT, UPDATE, DELETE, bulk operations | `references/dml.md` |
| Managing transactions, savepoints, isolation | `references/transactions.md` |

## Core vs ORM Quick Guide

| Use Core when | Use ORM when |
|---|---|
| CQRS read models / reporting queries | Domain model with business logic |
| Bulk inserts (thousands+ rows) | Single-entity CRUD |
| Data pipelines / ETL | Relationship navigation |
| Schema migrations | Change tracking / dirty checking |
| You want full SQL control | You want automatic persistence |

## Quick Reference: 1.x → 2.0 Changes

| 1.x (removed/deprecated) | 2.0 (use this) |
|---|---|
| `engine.execute(stmt)` | `with engine.connect() as conn: conn.execute(stmt)` |
| `MetaData(bind=engine)` | `metadata.create_all(engine)` |
| `conn.execute("SELECT ...")` | `conn.execute(text("SELECT ..."))` |
| Implicit autocommit | Explicit `conn.commit()` |
| `select([col1, col2])` | `select(col1, col2)` |
