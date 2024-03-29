DROP TABLE IF EXISTS t12;

CREATE TABLE t12 (
    t12id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    c1 int,
    c2 int,
    c3 text
);

INSERT INTO t12 (c1, c2)
SELECT
    trunc(random() * 100)::int,
    trunc(random() * 100)::int + 2
FROM
    generate_series(1, 10) g;


begin;
drop function if exists row_copy;
CREATE OR REPLACE FUNCTION row_copy (regclass, text, bigint)
    RETURNS bigint
    SET search_path TO public
    LANGUAGE plpgsql
    AS $func$
DECLARE
    _sql text;
    tmp text;
    row_ct bigint;
    col_ord int;
BEGIN
    IF (
        SELECT  a.attname = $2 and attidentity <> ''   
        FROM    pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
        WHERE
            i.indrelid = $1 AND i.indisprimary) 
        IS NOT TRUE THEN
        RAISE EXCEPTION '$2 should be the primary key column name and a idendity column';
    END IF;

    tmp := (
        SELECT  string_agg(quote_ident(attname), ', ')
        FROM    pg_attribute pa
        WHERE
            pa.attrelid = $1
            AND NOT attisdropped
            AND attnum > 0
            AND attname <> $2);

    _sql := format('insert into %1$s (%2$s) select %2$s from %1$s ', $1, tmp) || format(' where %s = %L', $2, $3);
    -- raise notice 'sql:%',_sql;
    EXECUTE _sql;
    get diagnostics row_ct = ROW_COUNT;
    RETURN row_ct;
END;
$func$;

BEGIN;
SELECT
    *
FROM
    row_copy ('t12', 't12id', 1);

TABLE t12;
ROLLBACK;

DROP TABLE t12;

COMMENT ON FUNCTION row_copy IS $$
https://dba.stackexchange.com/questions/122120/duplicate-row-with-primary-key-in-postgresql/122144#122144
$$;


