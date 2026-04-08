# SELECT Queries

## Basic SELECT

```python
from sqlalchemy import select

# All columns
stmt = select(users)
# SELECT users.id, users.name, users.email FROM users

# Specific columns
stmt = select(users.c.name, users.c.email)
# SELECT users.name, users.email FROM users

# Multiple columns via tuple accessor (2.0+)
stmt = select(users.c["name", "email"])

# Execute
with engine.connect() as conn:
    result = conn.execute(stmt)
    for row in result:
        print(row.name, row.email)
```

## WHERE Clauses

### Comparison Operators

```python
# Python operators map to SQL
users.c.name == "alice"           # name = :name_1
users.c.name != "alice"           # name != :name_1
users.c.age > 21                  # age > :age_1
users.c.age >= 21                 # age >= :age_1
users.c.age < 65                  # age < :age_1
users.c.age <= 65                 # age <= :age_1
```

### Column Methods

```python
users.c.name.in_(["alice", "bob"])            # name IN (:v1, :v2)
users.c.name.not_in(["alice", "bob"])         # name NOT IN (...)
users.c.age.between(18, 65)                   # age BETWEEN :a AND :b
users.c.name.like("%ali%")                    # name LIKE :pattern
users.c.name.ilike("%ali%")                   # name ILIKE :pattern (case-insensitive)
users.c.name.startswith("A")                  # name LIKE 'A' || '%'
users.c.name.endswith("ce")                   # name LIKE '%' || 'ce'
users.c.name.contains("li")                   # name LIKE '%' || 'li' || '%'
users.c.name.is_(None)                        # name IS NULL
users.c.name.is_not(None)                     # name IS NOT NULL
users.c.name.is_distinct_from("alice")        # name IS DISTINCT FROM :v
users.c.name.is_not_distinct_from("alice")    # name IS NOT DISTINCT FROM :v
```

### Boolean Logic

```python
from sqlalchemy import and_, or_, not_

# AND — three equivalent ways
stmt = select(users).where(users.c.name == "alice", users.c.age > 21)  # multiple args
stmt = select(users).where(users.c.name == "alice").where(users.c.age > 21)  # chained
stmt = select(users).where(and_(users.c.name == "alice", users.c.age > 21))  # explicit

# OR
stmt = select(users).where(or_(users.c.status == "active", users.c.status == "pending"))

# NOT
stmt = select(users).where(not_(users.c.is_deleted))

# Complex
stmt = select(users).where(
    and_(
        or_(users.c.name == "alice", users.c.name == "bob"),
        users.c.age > 21,
    )
)
# WHERE (name = :n1 OR name = :n2) AND age > :a1

# Operator syntax (& for AND, | for OR, ~ for NOT — REQUIRE parentheses!)
stmt = select(users).where(
    ((users.c.name == "alice") | (users.c.name == "bob")) & (users.c.age > 21)
)
```

### filter_by() — Shorthand for Equality

```python
stmt = select(users).filter_by(name="alice", status="active")
# WHERE name = :name_1 AND status = :status_1
```

## Column Selection and Labeling

```python
from sqlalchemy import func, literal_column

# Label (alias) a column
stmt = select(
    users.c.name,
    (users.c.first_name + " " + users.c.last_name).label("full_name"),
)
# SELECT name, first_name || ' ' || last_name AS full_name

# Scalar values
stmt = select(func.count(users.c.id).label("user_count"))
```

## JOINs

```python
# INNER JOIN — auto-detects FK relationship
stmt = select(users.c.name, addresses.c.email).join(addresses)
# FROM users JOIN addresses ON users.id = addresses.user_id

# Explicit ON clause
stmt = select(users, addresses).join(addresses, users.c.id == addresses.c.user_id)

# Explicit FROM and TO
stmt = select(users.c.name, addresses.c.email).join_from(users, addresses)

# LEFT OUTER JOIN
stmt = select(users).join(addresses, isouter=True)
stmt = select(users).outerjoin(addresses)  # shorthand

# FULL OUTER JOIN
stmt = select(users).join(addresses, full=True)

# select_from() — control the FROM clause explicitly
stmt = select(addresses.c.email).select_from(users).join(addresses)
# FROM users JOIN addresses ... — starts from users

# Aggregate with explicit FROM
stmt = select(func.count("*")).select_from(users)
```

## ORDER BY

```python
stmt = select(users).order_by(users.c.name)            # ASC (default)
stmt = select(users).order_by(users.c.name.desc())     # DESC
stmt = select(users).order_by(users.c.name.asc().nulls_last())  # NULLS LAST

# Multiple columns
stmt = select(users).order_by(users.c.last_name, users.c.first_name)

# By label name (string reference)
from sqlalchemy import desc
stmt = (
    select(users.c.name, func.count(addresses.c.id).label("addr_count"))
    .join(addresses)
    .group_by(users.c.name)
    .order_by("addr_count", desc("addr_count"))
)
```

## GROUP BY and HAVING

```python
from sqlalchemy import func

stmt = (
    select(users.c.name, func.count(addresses.c.id).label("count"))
    .join(addresses)
    .group_by(users.c.name)
    .having(func.count(addresses.c.id) > 1)
)
# SELECT name, count(addresses.id) AS count
# FROM users JOIN addresses ON ...
# GROUP BY name HAVING count(addresses.id) > :count_1

# Common aggregates
func.count(col)         # COUNT
func.sum(col)           # SUM
func.avg(col)           # AVG
func.min(col)           # MIN
func.max(col)           # MAX
func.count()            # COUNT(*) — use with select_from()
```

## LIMIT and OFFSET

```python
stmt = select(users).limit(10)                  # first 10 rows
stmt = select(users).offset(20)                 # skip 20 rows
stmt = select(users).limit(10).offset(20)       # rows 21-30
stmt = select(users).fetch(10)                  # SQL FETCH FIRST (alternative)
stmt = select(users).slice(20, 30)              # offset=20, limit=10
```

## DISTINCT

```python
stmt = select(users.c.name).distinct()
# SELECT DISTINCT name FROM users

# DISTINCT ON specific column (PostgreSQL only)
stmt = select(users).distinct(users.c.name)

# DISTINCT inside aggregate
from sqlalchemy import distinct
stmt = select(func.count(distinct(users.c.name)))
# SELECT count(DISTINCT name) FROM users
```

## Subqueries

```python
# Subquery in FROM (derived table)
subq = (
    select(func.count(addresses.c.id).label("count"), addresses.c.user_id)
    .group_by(addresses.c.user_id)
    .subquery()
)

stmt = select(users.c.name, subq.c.count).join_from(users, subq)
# FROM users JOIN (SELECT count(id) AS count, user_id FROM addresses GROUP BY user_id) AS anon_1
#   ON users.id = anon_1.user_id

# Access subquery columns
subq.c.count
subq.c.user_id
```

## Scalar Subqueries

```python
# Returns single value — usable in SELECT list or WHERE
subq = (
    select(func.count(addresses.c.id))
    .where(users.c.id == addresses.c.user_id)
    .scalar_subquery()
)

# In SELECT list
stmt = select(users.c.name, subq.label("address_count"))
# SELECT name, (SELECT count(id) FROM addresses WHERE users.id = addresses.user_id) AS address_count

# Explicit correlation (override auto-detection)
subq = (
    select(func.count(addresses.c.id))
    .where(users.c.id == addresses.c.user_id)
    .scalar_subquery()
    .correlate(users)
)
```

## Common Table Expressions (CTEs)

```python
# CTE — same API as subquery, just use .cte() instead of .subquery()
cte = (
    select(func.count(addresses.c.id).label("count"), addresses.c.user_id)
    .group_by(addresses.c.user_id)
    .cte()
)

stmt = select(users.c.name, cte.c.count).join_from(users, cte)
# WITH anon_1 AS (SELECT count(id) AS count, user_id FROM addresses GROUP BY user_id)
# SELECT name, anon_1.count FROM users JOIN anon_1 ON users.id = anon_1.user_id

# Named CTE
cte = (...).cte("top_users")
```

## EXISTS

```python
# EXISTS
subq = select(addresses.c.id).where(users.c.id == addresses.c.user_id).exists()
stmt = select(users.c.name).where(subq)
# WHERE EXISTS (SELECT addresses.id FROM addresses WHERE users.id = addresses.user_id)

# NOT EXISTS
stmt = select(users.c.name).where(~subq)
# WHERE NOT (EXISTS (...))
```

## UNION / INTERSECT / EXCEPT

```python
from sqlalchemy import union_all, union, intersect, except_

stmt1 = select(users).where(users.c.name == "alice")
stmt2 = select(users).where(users.c.name == "bob")

union_all(stmt1, stmt2)    # UNION ALL (keeps duplicates)
union(stmt1, stmt2)        # UNION (removes duplicates)
intersect(stmt1, stmt2)    # INTERSECT
except_(stmt1, stmt2)      # EXCEPT

# Use union result as subquery
u_subq = union_all(stmt1, stmt2).subquery()
stmt = select(u_subq.c.name).order_by(u_subq.c.name)
```

## Table Aliases (Self-Joins)

```python
u1 = users.alias("u1")
u2 = users.alias("u2")

stmt = select(u1.c.name, u2.c.name).join_from(
    u1, u2, u1.c.manager_id == u2.c.id
)
# FROM users AS u1 JOIN users AS u2 ON u1.manager_id = u2.id
```

## CASE Expressions

```python
from sqlalchemy import case

tier = case(
    (orders.c.total >= 1000, "gold"),
    (orders.c.total >= 100, "silver"),
    else_="bronze",
).label("tier")

stmt = select(orders.c.id, orders.c.total, tier)

# Dictionary form with value
priority = case(
    {"admin": 1, "moderator": 2, "user": 3},
    value=users.c.role,
    else_=99,
)
```

## SQL Functions (func)

```python
from sqlalchemy import func

func.count(col)                    # COUNT(col)
func.sum(col)                      # SUM(col)
func.avg(col)                      # AVG(col)
func.min(col)                      # MIN(col)
func.max(col)                      # MAX(col)
func.now()                         # NOW() / CURRENT_TIMESTAMP
func.current_timestamp()           # CURRENT_TIMESTAMP
func.coalesce(col, "default")     # COALESCE(col, 'default')
func.lower(col)                    # LOWER(col)
func.upper(col)                    # UPPER(col)
func.length(col)                   # LENGTH(col)
func.concat(a, b)                  # CONCAT(a, b)

# Namespaced functions
func.stats.percentile(col, 0.95)   # stats.percentile(col, 0.95)
```

## Other Expression Elements

```python
from sqlalchemy import cast, type_coerce, extract, literal, null, text, bindparam

# CAST
cast(col, Numeric(10, 2))         # CAST(col AS NUMERIC(10, 2))

# type_coerce — Python-side type without CAST in SQL
type_coerce(expr, String)

# EXTRACT
extract("year", col)               # EXTRACT(YEAR FROM col)

# Literal value as bind parameter
literal("some_value")

# NULL constant
null()

# Custom operators
col.op("||")(other_col)            # col || other_col
col.bool_op("@@")(query)           # col @@ query (PostgreSQL full-text)

# Bound parameters for reusable queries
stmt = select(users).where(users.c.id == bindparam("user_id"))
conn.execute(stmt, {"user_id": 42})
```

## LATERAL Subqueries (PostgreSQL)

```python
subq = (
    select(
        func.count(addresses.c.id).label("count"),
        addresses.c.email,
    )
    .where(users.c.id == addresses.c.user_id)
    .lateral()
)

stmt = select(users.c.name, subq.c.count, subq.c.email).join_from(users, subq)
# FROM users JOIN LATERAL (SELECT ...) AS anon_1 ON ...
```

## Result Processing

```python
with engine.connect() as conn:
    result = conn.execute(stmt)

    for row in result:
        print(row.name, row.email)          # Named tuple access

    for row in result.mappings():
        print(row["name"], row["email"])    # Dict-like access

    count = conn.execute(select(func.count()).select_from(users)).scalar()  # single value
    user = conn.execute(select(users).where(users.c.id == 1)).one()         # exactly one row
    names = conn.execute(select(users.c.name)).scalars().all()              # single column list
    rows = [dict(row._mapping) for row in result]                           # list of dicts
```

## Common Mistakes

- **`select([col1, col2])` (1.x style).** In 2.0, use `select(col1, col2)` — positional args, not a list.
- **Forgetting parentheses with `&` / `|` operators.** Python operator precedence requires `(a == 1) & (b == 2)`. Without parens, you get type errors.
- **Using `in_([])` (empty list).** Renders as `1 != 1` (always false). Check for empty lists before building the query if you need different behavior.
- **Subquery vs scalar_subquery confusion.** `subquery()` = table for FROM/JOIN. `scalar_subquery()` = single value for SELECT/WHERE.
- **`count()` without `select_from()`.** `select(func.count())` alone doesn't know which table. Use `select(func.count()).select_from(users)` or `select(func.count(users.c.id))`.
- **Forgetting `.label()` on computed columns.** Without a label, you can't reference the column by name in results.
