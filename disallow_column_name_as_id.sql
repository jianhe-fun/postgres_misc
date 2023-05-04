-- disable any user on any schema create new table specify  column name as id
-- alter table, alter materialzied view also not allow new column name as id.

CREATE OR REPLACE FUNCTION event_trigger_disable_column_name_id ()
    RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obj record;
    _object_identity text;
    command text;
BEGIN
    FOR obj IN
    SELECT
        *
    FROM
        pg_event_trigger_ddl_commands ()
        LOOP
            command := obj.command_tag;
            _object_identity := obj.object_identity;

            IF command IN ('CREATE MATERIALIZED VIEW', 'CREATE TABLE') THEN
                IF EXISTS (
                    SELECT
                    FROM
                        pg_attribute a
                    WHERE
                        a.attrelid = _object_identity::regclass
                        AND attname = 'id') THEN
                RAISE EXCEPTION 'table or materialized view  cannot have column name: "id"';
            END IF;
        END IF;
    IF command IN ('ALTER MATERIALIZED VIEW', 'ALTER TABLE') THEN
        IF (substring(_object_identity FROM (LENGTH(_object_identity) + 2 - STRPOS(REVERSE(_object_identity), '.'))) = 'id') THEN
            RAISE EXCEPTION 'alter table/materialized view  new column name cannot be: "id"';
        END IF;
    END IF;
END LOOP;
END;
$$;

DROP EVENT TRIGGER IF EXISTS event_trigger_disable_column_name_id_trg;
CREATE EVENT TRIGGER event_trigger_disable_column_name_id_trg ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE', 'CREATE MATERIALIZED VIEW', 'ALTER MATERIALIZED VIEW', 'ALTER TABLE')
        EXECUTE FUNCTION event_trigger_disable_column_name_id ();

--------------------------------------------------------------------------
---test
BEGIN;
ALTER TABLE t1 RENAME col1 TO id;
-- ERROR:  alter table/materialized view  new column name cannot be: "id"
-- CONTEXT:  PL/pgSQL function event_trigger_disable_column_name_id() line 33 at RAISE


BEGIN;
CREATE TABLE test_evetrg (id int);
-- ERROR:  table or materialized view  cannot have column name: "id"
-- CONTEXT:  PL/pgSQL function test_event_trigger_rel_with_id() line 22 at RAISE
END;

BEGIN;
CREATE MATERIALIZED VIEW test_mv AS
SELECT
    *
FROM
    a; -- table a already have column name as id.
-- ERROR:  table or materialized view  cannot have column name: "id"
-- CONTEXT:  PL/pgSQL function test_event_trigger_rel_with_id() line 22 at RAISE
END;