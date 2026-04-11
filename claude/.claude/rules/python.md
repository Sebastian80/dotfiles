---
alwaysApply: false
paths: **/*.py, pyproject.toml, uv.lock
---

# Python

- Use the `python-cosmic` skill for architectural guidance (DDD, Repository, UoW, Aggregates, hexagonal mapping).
- Use the `python-sqlalchemy-core` skill for SQLAlchemy 2.0 Core work (Engine, Connection, expression language, schema).
- Use the `python-sqlalchemy-cosmic` skill for SQLAlchemy in a Cosmic Python project (imperative mapping, Unit of Work session lifecycle, 1.x→2.0 migration).
- See `toolchain.md` for package manager rules (uv for everything, never bare `pip` or `python -m pip`).
