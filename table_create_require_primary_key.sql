/*
newly created table must explicit set primary key.
*/
DROP EVENT TRIGGER table_create_require_primary_key;

CREATE OR REPLACE FUNCTION table_create_require_primary_key()
    RETURNS event_trigger
    LANGUAGE plpgsql
    SET search_path FROM    current
    AS $$
DECLARE
    obj record;
    table_name text;
    n bigint;
BEGIN
    FOR obj IN
    SELECT
        *
    FROM
        pg_event_trigger_ddl_commands ()
        LOOP
--         RAISE NOTICE 'classid: % objid: %,object_type: %
-- object_identity: % schema_name: % command_tag: %' , obj.classid , obj.objid , obj.object_type , obj.object_identity , obj.schema_name , obj.command_tag;
            IF obj.command_tag = 'CREATE TABLE' THEN
                table_name := obj.object_identity;
            END IF;
        END LOOP;
    PERFORM
    FROM
        pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid
            AND a.attnum = ANY (i.indkey)
    WHERE
        i.indisprimary
        AND i.indrelid = table_name::regclass;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'primary key must explicitly set.';
    END IF;
END;
$$;

CREATE EVENT TRIGGER table_create_require_primary_key ON ddl_command_end
    WHEN TAG IN ('CREATE TABLE')
        EXECUTE FUNCTION table_create_require_primary_key ();

----- test time.
DROP TABLE if exists a3,a4,a5 cascade;
CREATE TABLE a3 (a int);
/*
ERROR:  primary key must explicitly set.
CONTEXT:  PL/pgSQL function table_require_primary_key() line 28 at RAISE
*/
CREATE TABLE a4 (a int PRIMARY KEY);
CREATE TABLE a5 (a1 int UNIQUE NOT NULL); 
/*
ERROR:  primary key must explicitly set.
CONTEXT:  PL/pgSQL function table_require_primary_key() line 28 at RAISE
*/

--clean up.
DROP TABLE if exists a3,a4,a5 cascade;