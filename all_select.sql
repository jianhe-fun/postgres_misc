/*
    *query current database all relations {table,view, materialized view, partitioned table} 
    that are allowed to 'SELECT' by every role.
*/
DROP VIEW all_select;
CREATE OR REPLACE VIEW public.all_select AS
SELECT
    pn.nspname,
    c.relname,
    c.relkind,
    pl.rolname AS owner
FROM
    pg_class c
    JOIN pg_namespace pn ON pn.oid = c.relnamespace
    CROSS JOIN LATERAL aclexplode(COALESCE(c.relacl, acldefault('r'::"char", c.relowner))) s (grantor,
        grantee,
        privilege_type,
        is_grantable)
    JOIN pg_roles pl ON pl.oid = c.relowner
WHERE
    s.privilege_type = 'SELECT'::text
    AND (c.relkind = ANY (ARRAY['r'::"char", 'm'::"char", 'p'::"char", 'v'::"char"]))
    AND s.grantee = 0::oid
ORDER BY
    pn.nspname;

REVOKE ALL on public.all_select from public;
GRANT   SELECT on public.all_select to public;

table all_select;