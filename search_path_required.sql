/*
    any role when create a new function
        * must explicitly set the search_path.
        * at least one of the search_path can be visible by the function creator.
*/
set role jian; --superuser
DROP EVENT TRIGGER IF EXISTS trig_search_path_required;

DROP EVENT TRIGGER IF EXISTS search_path_required;

CREATE OR REPLACE FUNCTION public.search_path_required()
RETURNS event_trigger  SET SEARCH_PATH FROM CURRENT LANGUAGE plpgsql
AS $function$
DECLARE
    obj                 record;
    _object_identity    text;
    command             text;
    visible_schemas     text[];
    tmp                 text[];
BEGIN
    FOR obj IN  SELECT * FROM pg_event_trigger_ddl_commands() LOOP
        command          := obj.command_tag;
        _object_identity := obj.object_identity;
            IF command IN ('CREATE FUNCTION', 'ALTER FUNCTION') THEN
                SELECT  array_agg(pn.nspname::text) INTO    visible_schemas
                FROM    pg_namespace    pn
                WHERE   has_schema_privilege(CURRENT_USER, pn.oid, 'USAGE');

                IF visible_schemas IS NULL THEN
                    raise exception 'current user have no usage of any schema. abort';
                END IF;

                SELECT  string_to_array(substring(pconfig::text from 'search_path=(.*)$'),', ') INTO tmp
                FROM    pg_proc         pp
                JOIN    pg_namespace    pn  ON  pn.oid  =   pp.pronamespace
                JOIN    pg_language     pl  ON  pl.oid  =   pp.prolang
                CROSS   JOIN        unnest(pp.proconfig) s(pconfig)
                WHERE   lanname IN ('sql', 'plpgsql','c')       
                AND     s.pconfig ~* 'search_path'
                AND     pn.nspname || '.' || pp.proname = substring(_object_identity FOR strpos(_object_identity, '(') - 1)
                GROUP   BY  pconfig;

                -- raise notice '_object_identity: %',_object_identity;
                -- raise notice 'tmp %, visible_schemas %',tmp, visible_schemas;

                IF  (array_length(tmp, 1) IS NULL)   THEN
                    RAISE EXCEPTION E'new created function require explicit set the search_paths.\nAlso the function owner should have USAGE for the specified search_paths.';
                ELSIF  (tmp && visible_schemas) IS FALSE THEN
                    RAISE EXCEPTION E'new created function require explicit set the search_paths.\nAlso the function owner should have USAGE for the specified search_paths.';
                END IF;
            END IF;
        END LOOP;
END;
$function$;

CREATE EVENT TRIGGER search_path_required ON ddl_command_end
WHEN tag IN ('CREATE FUNCTION', 'ALTER FUNCTION')
EXECUTE FUNCTION search_path_required();

--------------------------------------------------------------------------------------------------------
--available schemas.
BEGIN;
SET ROLE TEST;
SELECT
    string_agg(pn.nspname::text, ', ') AS usage_schems
FROM
    pg_namespace pn
WHERE
    has_schema_privilege(CURRENT_USER, pn.oid, 'USAGE')
    AND pn.nspname <> 'information_schema'
    AND pn.nspname !~* 'pg_';

/*
               usage_schems
-------------------------------------------
 override, test_priv, public, test, search
(1 row)
*/
DROP FUNCTION IF EXISTS func_test1, func_test2, func_test3, func_test4;
COMMIT;


-- fail. search_path does not visible to function owner.
BEGIN;
    set role test;
    CREATE OR REPLACE FUNCTION func_test0(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
    LANGUAGE plpgsql
    set search_path = regress_indexing
    AS $func$
    BEGIN
    EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
    USING $1, $2 INTO _reuslt;
    END;
    $func$;
ROLLBACK;

-- ok to use set search_path from current.
BEGIN;
    set role test;
    
    CREATE OR REPLACE FUNCTION func_test0(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
    LANGUAGE plpgsql
    set search_path from current
    AS $func$
    BEGIN
    EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
    USING $1, $2 INTO _reuslt;
    END;
    $func$;
ROLLBACK;

--fail. not explicitly set the search_path.
BEGIN;
    set role test;
    CREATE OR REPLACE FUNCTION func_test1(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
    LANGUAGE plpgsql
    AS $func$
    BEGIN
    EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
    USING $1, $2 INTO _reuslt;
    END;
    $func$;
ROLLBACK;


--fail. not explicitly set the search_path.
BEGIN;
    CREATE OR REPLACE FUNCTION func_test2(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
    LANGUAGE plpgsql
    set time zone  'Europe/Rome'
    set datestyle to   postgres, dmy
    AS $func$
    BEGIN
    EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
    USING $1, $2 INTO _reuslt;
    END;
    $func$;
ROLLBACK;

-- fail. newly settled search_path does not visible to function owner.
BEGIN;
    set role test;
    CREATE OR REPLACE FUNCTION func_test3(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
    LANGUAGE plpgsql
    set time zone  'Europe/Rome'
    set datestyle to   postgres, dmy
    set search_path = regress_indexing
    AS $func$
    BEGIN
    EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
    USING $1, $2 INTO _reuslt;
    END;
    $func$;
ROLLBACK;

--ok.search_path some is visible, some not.
BEGIN;
    set role test;
    CREATE OR REPLACE FUNCTION func_test4(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
    LANGUAGE plpgsql
    set search_path = regress_indexing,public,fkpart3,fkpart4
    set time zone  'Europe/Rome'
    set datestyle to   postgres, dmy
    AS $func$
    BEGIN
    EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
    USING $1, $2 INTO _reuslt;
    END;
    $func$;
COMMIT;

--ok
BEGIN;
    SET ROLE TEST;
    CREATE OR REPLACE FUNCTION func_test5 (_operand1 int, _operand2 int, _operator text, out _reuslt bool)
    LANGUAGE plpgsql
    set search_path = public
    AS $func$
    BEGIN
    EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
    USING $1, $2 INTO _reuslt;
    END;
    $func$;
COMMIT;

-- fail. after alter function, search_path will be reset.
ALTER FUNCTION public.func_test5 (int, int, text) RESET search_path;

--CLEAN UP.
drop function if exists func_test1, func_test2, func_test3, func_test4;
