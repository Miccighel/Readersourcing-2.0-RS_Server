\set ON_ERROR_STOP on
SET statement_timeout = '30s';
SET lock_timeout = '5s';
BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL timezone = 'UTC';

SELECT format($query$
  SELECT json_build_object(
    'kind', 'table', 'name', %L, 'rows', count(*),
    'sha256', encode(sha256(convert_to(coalesce(string_agg(row_text, E'\n' ORDER BY row_text COLLATE "C"), ''), 'UTF8')), 'hex')
  )::text
  FROM (SELECT to_jsonb(entry)::text AS row_text FROM %I.%I AS entry) AS source;
$query$, namespace.nspname || '.' || relation.relname, namespace.nspname, relation.relname)
FROM pg_class AS relation
JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
WHERE namespace.nspname = 'public' AND relation.relkind IN ('r', 'p')
ORDER BY relation.relname COLLATE "C"
\gexec

SELECT format($query$
  SELECT json_build_object(
    'kind', 'sequence', 'name', %L,
    'sha256', encode(sha256(convert_to(jsonb_build_object('last_value', last_value, 'is_called', is_called)::text, 'UTF8')), 'hex')
  )::text FROM %I.%I;
$query$, namespace.nspname || '.' || relation.relname, namespace.nspname, relation.relname)
FROM pg_class AS relation
JOIN pg_namespace AS namespace ON namespace.oid = relation.relnamespace
WHERE namespace.nspname = 'public' AND relation.relkind = 'S'
ORDER BY relation.relname COLLATE "C"
\gexec

COMMIT;
