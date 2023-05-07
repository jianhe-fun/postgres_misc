
/*
https://dba.stackexchange.com/questions/102957/postgresql-force-upper-case-for-all-data/102998#102998

trigger force_upper_all will force any text columns in a specified table (trigger target table) to be upper($col).
trigger force_upper_cola_trig will force column cola in public.test_upper_cola to be upper.

*/

BEGIN;
DROP TABLE IF EXISTS test_upper;
CREATE TABLE public.test_upper (
    cola text,
    colb text,
    colc numeric
);

CREATE OR REPLACE FUNCTION public.force_upper_all()
    RETURNS TRIGGER
    SET search_path
FROM
    current
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

CREATE OR REPLACE TRIGGER force_upper_all
    BEFORE INSERT OR UPDATE ON test_upper
    FOR EACH ROW
    EXECUTE FUNCTION public.force_upper();

COMMIT;

--test time.
INSERT INTO test_upper VALUES ('120lo', 'sdklj', 12.1)     RETURNING *;
INSERT INTO test_upper VALUES ('x', 'basdas', 1.223432)    RETURNING *;

--clean up
DROP TABLE IF EXISTS test_upper CASCADE;
------------------------------------------------------------------------------------------
-- one column upper.
BEGIN;
DROP TABLE IF EXISTS test_upper_cola;

CREATE TABLE public.test_upper_cola (
    cola text,
    colb text,
    colc numeric
);

CREATE OR REPLACE FUNCTION public.force_upper_cola()
    RETURNS TRIGGER
    SET search_path FROM    current
    AS $func$
DECLARE
BEGIN
    new.cola    := upper(new.cola);
    return      new;
END
$func$
LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER force_upper_cola_trig
    BEFORE INSERT OR UPDATE ON  test_upper_cola
    FOR EACH ROW
    WHEN(new.cola is not null)
    EXECUTE FUNCTION public.force_upper_cola();
COMMIT;

--test time.
INSERT INTO test_upper_cola VALUES ('120lo', 'sdklj', 12.1)     RETURNING *;
INSERT INTO test_upper_cola VALUES ('x', 'basdas', 1.223432)    RETURNING *;
INSERT INTO test_upper_cola VALUES (NULL, 'basdas', 1.223432)    RETURNING *;

----clean up
drop table test_upper_cola cascade;
drop function public.force_upper_cola() cascade;
