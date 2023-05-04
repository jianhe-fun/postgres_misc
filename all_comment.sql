
/*
extract comment from following objects.
    * current_database
    * schemas   meet criteria X
    * constraint comment in schemas meet criteria X
    * {table,index,Sequence,view,'materialized view'
        ,'composite type','foreign table','partitioned table''partitioned index'} in schemas meet criteria X
    * column comment in schemas meet criteria X
    * {normal function,procedure, aggregate function, window function} comment in schemas meet criteria X

    X = schema_name <> 'information_schema'::text AND schema_name !~* '^pg_'
*/
COMMENT ON VIEW all_comment IS $$ the above comment $$;
REVOKE all on table all_comment from public;
GRANT SELECT ON TABLE all_comment TO public;

CREATE OR REPLACE VIEW all_comment AS
(
------------database comment-------------------
    SELECT
        NULL::text,
        text 'database' AS kind,
        pd.datname,
        pg_catalog.obj_description(pd.oid, 'pg_database') AS description
    FROM
        pg_catalog.pg_database pd
    WHERE
        pg_catalog.obj_description(pd.oid, 'pg_database') IS NOT NULL
        AND pd.datname = current_database()
) 
UNION ALL(
------------schema comment-------------------
    SELECT
        pn.nspname AS schema,
        'schema' AS kind,
        pn.nspname,
        pg_catalog.obj_description(pn.oid, 'pg_namespace') AS description
    FROM
        pg_catalog.pg_namespace pn
    WHERE
        pg_catalog.obj_description(pn.oid, 'pg_namespace') IS NOT NULL
        AND pn.nspname !~* '^pg_'
        AND pn.nspname <> 'information_schema'::text
)
UNION ALL(
------------constraint comment-------------------
    SELECT
        pcon.connamespace::regnamespace::text AS schema,
        CASE contype
        WHEN 'c' THEN
            'check_constraint'
        WHEN 'f' THEN
            'foreign key'
        WHEN 'p' THEN
            'primary key'
        WHEN 'u' THEN
            'unique'
        WHEN 't' THEN
            'constraint trigger'
        WHEN 'x' THEN
            'exclusion constraint'
        END AS kind,
        pcon.conname,
        pg_catalog.obj_description(pcon.oid, 'pg_constraint') AS description
    FROM
        pg_constraint pcon
    WHERE
        pg_catalog.obj_description(pcon.oid, 'pg_constraint') IS NOT NULL
        AND pcon.connamespace::regnamespace::text <> 'information_schema'::text
        AND pcon.connamespace::regnamespace::text !~* '^pg_'
)
UNION ALL(        
------------relation (table, view, sequence, index etc) comment-------------------
    SELECT
        pc.relnamespace::regnamespace::text AS schema,
        CASE pc.relkind
        WHEN 'r' THEN
            'table'
        WHEN 'i' THEN
            'index'
        WHEN 'S' THEN
            'Sequence'
        WHEN 'v' THEN
            'view'
        WHEN 'm' THEN
            'materialized view'
        WHEN 'c' THEN
            'composite type'
        WHEN 'f' THEN
            'foreign table'
        WHEN 'p' THEN
            'partitioned table'
        WHEN 'I' THEN
            'partitioned index'
        END AS kind,
        pc.relname,
        pg_catalog.obj_description(pc.oid, 'pg_class') AS description
    FROM
        pg_class pc
    WHERE
        pg_catalog.obj_description(pc.oid, 'pg_class') IS NOT NULL
        AND pc.relnamespace::regnamespace::text <> 'information_schema'::text
        AND pc.relnamespace::regnamespace::text !~* '^pg_'
)
UNION ALL(        
------------column comment--------------------------------------
    SELECT
        pc.relnamespace::regnamespace::text AS schema,
        text 'column ' AS kind,
        pc.relname || '.' || pa.attname AS column_full_name,
        pd.description
    FROM
        pg_description pd
        JOIN pg_class pc ON pd.objoid = pc.oid
        JOIN pg_attribute pa ON pc.oid = pa.attrelid
    WHERE
        pd.objsubid <> 0
        AND pa.attnum = pd.objsubid
        AND pc.relnamespace::regnamespace::text <> 'information_schema'::text
        AND pc.relnamespace::regnamespace::text !~* '^pg_'
)
UNION ALL(        
------------function procedure, aggregate, window comment-------------------
    SELECT
        pronamespace::regnamespace::text,
        pp.proname,
        CASE prokind
        WHEN 'f' THEN
            'function'
        WHEN 'p' THEN
            'procedure'
        WHEN 'a' THEN
            'aggregate'
        WHEN 'w' THEN
            'window'
        END AS kind,
        pg_catalog.obj_description(pp.oid, 'pg_proc') AS description
    FROM
        pg_catalog.pg_proc pp
    WHERE
        pg_catalog.obj_description(pp.oid, 'pg_proc') IS NOT NULL
        AND pp.pronamespace::regnamespace::text <> 'information_schema'::text
        AND pp.pronamespace::regnamespace::text !~* '^pg_'
);  