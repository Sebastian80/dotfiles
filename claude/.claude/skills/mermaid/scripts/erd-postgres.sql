-- Mermaid erDiagram for a set of Postgres tables, straight from the catalog.
-- Uses pg_catalog (fast on 1000+ table schemas; information_schema views are
-- not). Run with psql, tables as a comma-separated psql variable:
--
--   psql "$DSN" -qtA -v tables='oro_order,oro_order_line_item' -f erd-postgres.sql
--   docker exec -i <db-container> psql -U <user> -d <db> -qtA -v tables='…' -f - < erd-postgres.sql
--
-- Cardinality: FK column NOT NULL → ||--o{ (mandatory parent), nullable → |o--o{.
-- One-to-one (FK column is unique) → ||--|| / |o--||.
\set tbl_array '''{' :tables '}'''
with wanted as (
    select c.oid, c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relkind in ('r', 'p')
      and n.nspname = current_schema()
      and c.relname = any (:tbl_array::text[])
),
cols as (
    select w.relname,
           a.attnum,
           a.attname,
           t.typname as coltype,
           exists (select 1 from pg_constraint p
                   where p.conrelid = w.oid and p.contype = 'p' and a.attnum = any (p.conkey)) as is_pk,
           exists (select 1 from pg_constraint f
                   where f.conrelid = w.oid and f.contype = 'f' and a.attnum = any (f.conkey)) as is_fk,
           exists (select 1 from pg_constraint u
                   where u.conrelid = w.oid and u.contype = 'u' and a.attnum = any (u.conkey)) as is_uk
    from wanted w
    join pg_attribute a on a.attrelid = w.oid and a.attnum > 0 and not a.attisdropped
    join pg_type t on t.oid = a.atttypid
),
fks as (
    select child.relname as child, parent.relname as parent,
           a.attname as fk_col, a.attnotnull as mandatory,
           exists (select 1 from pg_constraint u
                   where u.conrelid = child.oid and u.contype in ('u', 'p') and u.conkey = f.conkey) as one_to_one
    from pg_constraint f
    join wanted child  on child.oid  = f.conrelid
    join wanted parent on parent.oid = f.confrelid
    join pg_attribute a on a.attrelid = f.conrelid and a.attnum = f.conkey[1]
    where f.contype = 'f' and array_length(f.conkey, 1) = 1
)
select line from (
    select 0 as grp, '' as tbl, 0 as seq, 'erDiagram' as line
    union all
    select 1, relname, 0, format('    %s {', relname) from wanted
    union all
    select 1, relname, attnum,
           format('        %s %s %s', coltype, attname,
                  concat_ws(',', case when is_pk then 'PK' end,
                                 case when is_fk then 'FK' end,
                                 case when is_uk and not is_pk then 'UK' end))
    from cols
    union all
    select 1, relname, 100000, '    }' from wanted
    union all
    select 2, parent, 0,
           format('    %s %s--%s %s : %s', parent,
                  case when mandatory then '||' else '|o' end,
                  case when one_to_one then '||' else 'o{' end,
                  child, fk_col)
    from fks
) rows
order by grp, tbl, seq;
