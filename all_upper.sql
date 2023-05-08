
/*
https://dba.stackexchange.com/questions/102957/postgresql-force-upper-case-for-all-data/102998#102998

trigger force_upper_all will force any text columns in a specified table (trigger target table) to be upper($col).
trigger force_upper_cola_trig will force column cola in public.test_upper_cola to be upper.

*/

BEGIN;
DROP TABLE IF EXISTS t13;

create table t13(
    c1  text
    ,c2 text    GENERATED ALWAYS AS (c1 || '_hello') STORED
    ,c3 text default  'yes'
    ,c4 int GENERATED by default as IDENTITY
    );

drop function if exists public.upper_this();

CREATE OR REPLACE FUNCTION public.upper_this()
    RETURNS TRIGGER
    SET search_path FROM    current
    AS $func$
DECLARE
    _sql text;
    _typ CONSTANT regtype[] := '{text,bpchar,name, varchar}';
    _found bool;
BEGIN
    SELECT
        INTO _sql,
        _found 'select ' || string_agg(
            CASE WHEN a.atttypid = ANY (_typ) THEN
                format('upper(%1$s) as %1$s ', a.col, a.col)
            ELSE
                col
            END, ', ') || ' FROM (select ($1).*) t',
        bool_or(a.atttypid = ANY (_typ))
    FROM (
        SELECT
            a.atttypid,
            quote_ident(attname) AS col
        FROM
            pg_attribute a
        WHERE
            a.attrelid = TG_RELID
            AND a.attnum >= 1
            AND NOT a.attisdropped) a;
    IF _found THEN
        EXECUTE _sql
        USING new INTO new;
    END IF;
        RETURN new;
END
$func$
LANGUAGE plpgsql;

COMMIT;

------------------------------------------------------------------------------------------

------------test for c1, c3 columns.
BEGIN;
CALL generic_text_trigger_transform('t13', '{c1,c3}', 'upper_this');

INSERT INTO t13 (c1, c3)
SELECT
    chr(chr_d) || ' test my string    ' || chr(chr_d),
    chr(chr_d) || ' test my string ' || random()::numeric(10, 3) || chr(chr_d)
FROM (
    SELECT
        unnest('{9,32,160,5760,6158,8239,8287,8288,12288,65279}'::int[])
    UNION ALL
    SELECT
        generate_series(8192, 8202) AS dec -- UNICODE "Spaces"
    UNION ALL
    SELECT
        generate_series(8203, 8207) AS dec -- First 5 space-like UNICODE "Format characters"
) t (chr_d)
WHERE
    chr(chr_d) ~ '\s' IS FALSE;

SELECT  count(*)    as should_be_zero
FROM    t13 
where   c1 IS not null and c3 is not null
and     c3 !~ 'TEST MY STRING' 
OR      c1 !~ 'TEST MY STRING';

ROLLBACK;


------------test for col3 upper, strip white spaces in c1 columns.
BEGIN;

CALL generic_text_trigger_transform ('t13', '{c3,c1}', 'upper_this');
CALL generic_text_trigger_transform ('t13', '{c1}', 'strip');

INSERT INTO t13 (c1, c3)
SELECT
    chr(chr_d) || ' test my string    ' || chr(chr_d),
    chr(chr_d) || ' test my string ' || random()::numeric(10, 3) || chr(chr_d)
FROM (
    SELECT
        unnest('{9,32,160,5760,6158,8239,8287,8288,12288,65279}'::int[])
    UNION ALL
    SELECT
        generate_series(8192, 8202) AS dec -- UNICODE "Spaces"
    UNION ALL
    SELECT
        generate_series(8203, 8207) AS dec -- First 5 space-like UNICODE "Format characters"
) t (chr_d)
WHERE
    chr(chr_d) ~ '\s' IS FALSE;

SELECT  count(*)    as should_be_zero
FROM    t13
WHERE   c1 is not null and length(c1) <> 14;

SELECT  count(*)    as should_be_zero
FROM    t13
where   c1 IS not null 
and     c3 is not null
and     c3 !~ 'TEST MY STRING' 
OR      c1 !~ 'TEST MY STRING';

ROLLBACK;

--clean up
DROP TABLE IF EXISTS t13 CASCADE;
