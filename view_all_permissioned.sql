/*
check permisssion in following object: database, parameter (superuser granted), schema, table, view, materialzied view
    ,column,function, sequence for  (eveery roles except superuser).
predefined role also checked permission against all the objects.

*/
CREATE OR REPLACE VIEW public.permission_view AS
    (
---------------------database permission---------------    
        SELECT
            NULL::text AS obj_schema,
            text 'database' AS kind,
            pd.datname::text AS obj_name,
            rolname AS role,
            priv AS privilege
        FROM
            pg_database pd
        CROSS JOIN (
            VALUES ('CREATE'),
                ('CONNECT'),
                ('TEMPORARY')) s (priv)
            CROSS JOIN pg_roles pr
        WHERE
            NOT pr.rolsuper
                AND pd.datname = current_database()
                AND has_database_privilege(pr.oid, pd.oid, priv))
    UNION ALL
    (
---------------------parameter permission---------------    
        SELECT
            NULL::text AS obj_schema,
            text 'parameter' AS kind,
            ppa.parname AS obj_name,
            rolname,
            priv privilege
        FROM
            pg_parameter_acl ppa
        CROSS JOIN (
            VALUES ('ALTER SYSTEM'),
                ('SET')) s (priv)
            CROSS JOIN pg_roles pr
        WHERE
            NOT pr.rolsuper
                AND has_parameter_privilege (pr.oid, ppa.parname, priv)
    )
---------------------schema permission---------------
    UNION ALL (
        SELECT
            pn.nspname::text AS schema,
            text 'schema' AS kind,
            pn.nspname::text AS obj_name,
            rolname,
            priv privilege
        FROM
            pg_namespace pn
        CROSS JOIN pg_roles pr
        CROSS JOIN (
            VALUES ('CREATE'),
                ('USAGE')) s (priv)
        WHERE
            NOT pr.rolsuper
                AND pn.nspname::text <> 'information_schema'::text
                AND NOT pn.nspname::text ~* '^pg_'
                AND has_schema_privilege(pr.oid, pn.oid, priv))
    UNION ALL
    (
----------------------------------------table,view, materialized view permission---------------    
        SELECT
            pc.relnamespace::regnamespace::text AS schema,
            CASE pc.relkind
            WHEN 'r' THEN
                text 'table'
            WHEN 'v' THEN
                'view'
            WHEN 'm' THEN
                'matview'
            END AS kind,
            pc.relname::text, --relation name
            rolname,
            priv privilege
        FROM
            pg_class pc
        CROSS JOIN (
            VALUES ('SELECT'),
                ('INSERT'),
                ('UPDATE'),
                ('DELETE'),
                ('TRUNCATE'),
                ('REFERENCES'),
                ('TRIGGER'),
                ('MAINTAIN')) s (priv)
            CROSS JOIN pg_roles pr
        WHERE
            NOT pr.rolsuper
                AND pc.relnamespace::regnamespace::text <> 'information_schema'::text
                AND NOT pc.relnamespace::regnamespace::text ~* '^pg_'
                AND has_table_privilege(pr.oid, pc.oid, priv))
    UNION ALL 
    (
----------------column permission---------------
    SELECT
        pc.relnamespace::regnamespace::text AS schema,
        text 'column' AS kind,
        pc.relname::text || '.' || pa.attname AS rel_col,
        rolname,
        priv privilege
    FROM
        pg_class pc
        JOIN pg_attribute pa ON pa. attrelid = pc.oid
        CROSS JOIN pg_roles pr
        CROSS JOIN (
            VALUES ('SELECT'),
                ('INSERT'),
                ('UPDATE'),
                ('REFERENCES')) s (priv)
        WHERE
            pc.relnamespace::regnamespace::text <> 'information_schema'::text
                AND has_column_privilege(pr.oid, pc.oid, pa.attnum, priv)
                AND NOT pr.rolsuper
                AND NOT pc.relnamespace::regnamespace::text ~* '^pg_'
                AND relkind IN ('r', 'm', 'v')
                AND pa.attnum > 0
    )
    UNION ALL 
    (
------------------------------------------function permission------------------------------
        SELECT
            pp.pronamespace::regnamespace::text AS object_schema,
            text 'function' AS kind,
            pp.oid::regprocedure::text AS obj_name,
            rolname,
            priv privilege
        FROM
            pg_proc pp
        CROSS JOIN (
            VALUES ('EXECUTE')) s (priv)
            CROSS JOIN pg_roles pr
        WHERE
            NOT pr.rolsuper
                AND has_function_privilege(pr.oid, pp.oid, priv)
                AND pp.pronamespace <> 'information_schema'::regnamespace
                AND NOT pp.pronamespace::regnamespace::text ~* '^pg_'
                AND prolang <> (
                    SELECT
                        oid
                    FROM
                        pg_language
                    WHERE
                        lanname = 'c')
    )
    UNION ALL 
    (
------------------------------------------sequence permission---------------            
        SELECT
            pc.relnamespace::regnamespace::text AS schema, --schema
            text 'sequence' AS kind,
            pc.relname::text AS obj_name, --relation name
            rolname,
            priv privilege
        FROM
            pg_class pc
        CROSS JOIN (
            VALUES ('USAGE'),
                ('SELECT'),
                ('UPDATE')) s (priv)
            CROSS JOIN pg_roles pr
        WHERE
            NOT pr.rolsuper
                AND has_sequence_privilege(pr.oid, pc.oid, priv)
                AND pc.relnamespace <> 'information_schema'::regnamespace
                AND NOT pc.relnamespace::text ~* '^pg_'
                AND pc.relkind = 'S'::"char"
    );

