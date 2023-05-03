/*
    any role when create a new function
        * must explicitly set the search_path.
        * at least one of the search_path can be visible by the function creator.
*/
set role jian; --superuser
DROP EVENT TRIGGER IF EXISTS trig_search_path_required;

CREATE OR REPLACE FUNCTION public.func_search_path_required()
 RETURNS event_trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    obj                 record;
    _object_identity    text;
    command             text;
    schema_exists_also_visible   bool;
BEGIN
    FOR obj IN
    SELECT
        *
    FROM
        pg_event_trigger_ddl_commands ()
        LOOP
            command := obj.command_tag;
            _object_identity := obj.object_identity;
            IF command IN ('CREATE FUNCTION', 'ALTER FUNCTION') THEN
                select 
                        string_to_array(substring(pconfig::text from 'search_path=(.*)$'),', ')   && array_agg(pn.nspname::text)
                    FROM    pg_proc         pp
                    JOIN    pg_namespace    pn  ON  pn.oid  =   pp.pronamespace
                    JOIN    pg_language     pl  ON  pl.oid  =   pp.prolang
                    cross   join unnest(pp.proconfig) s(pconfig)
                    WHERE   lanname IN ('sql', 'plpgsql')
                    AND     has_schema_privilege(CURRENT_USER, pn.oid, 'USAGE')
                    and     pn.nspname <> 'information_schema'
                    AND     pn.nspname !~* 'pg_'
                    and     s.pconfig ~* 'search_path='
                    AND pronamespace::regnamespace::text || '.' || pp.proname
                            = substring(_object_identity FOR strpos(_object_identity, '(') - 1)
                    group   by pconfig
                INTO schema_exists_also_visible;
                -- raise notice 'test% obj_identity:%',schema_exists_also_visible, _object_identity;
                if schema_exists_also_visible is not true then 
                    RAISE EXCEPTION E'new created function require explicit set the search_paths.\nAlso the function owner should have USAGE for the specified search_paths.';
                END IF;
            END IF;
        END LOOP;
END;
$function$;
CREATE EVENT TRIGGER trig_search_path_required ON ddl_command_end
WHEN tag IN ('CREATE FUNCTION', 'ALTER FUNCTION')
EXECUTE FUNCTION func_search_path_required();

--------------------------------------------------------------------------------------------------------
--available schemas.
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

drop function if exists func_test1, func_test2, func_test3, func_test4;
set role test;


-- fail. search_path does not visible to function owner.
CREATE OR REPLACE FUNCTION func_test0(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
LANGUAGE plpgsql
set search_path = regress_indexing
AS $func$
BEGIN
EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
USING $1, $2 INTO _reuslt;
END;
$func$;

--fail. not explicitly set the search_path.
CREATE OR REPLACE FUNCTION func_test1(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
LANGUAGE plpgsql
AS $func$
BEGIN
EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
USING $1, $2 INTO _reuslt;
END;
$func$;

--fail. not explicitly set the search_path.
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

-- fail. newly settled search_path does not visible to function owner.
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

--ok.search_path some is visible, some not.
CREATE OR REPLACE FUNCTION func_test4(_operand1 int, _operand2 int, _operator text, out _reuslt bool)
LANGUAGE plpgsql
set search_path = regress_indexing,public,fkpart3,fkpart4
AS $func$
BEGIN
EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
USING $1, $2 INTO _reuslt;
END;
$func$;

--ok
CREATE OR REPLACE FUNCTION func_test5 (_operand1 int, _operand2 int, _operator text, out _reuslt bool)
LANGUAGE plpgsql
set search_path = public
AS $func$
BEGIN
EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
USING $1, $2 INTO _reuslt;
END;
$func$;

-- fail. after alter function, search_path will be reset.
ALTER FUNCTION public.func_test5 (int, int, text) RESET search_path;

-- fail. since schema not visiable (not exists)
CREATE OR REPLACE FUNCTION func_test6 (_operand1 int, _operand2 int, _operator text, out _reuslt bool)
LANGUAGE plpgsql
set search_path = not_exists_schema
AS $func$
BEGIN
EXECUTE format('select  $1 operator (%s) $2', (_operator || '(int,int)')::regoperator::regoper)
USING $1, $2 INTO _reuslt;
END;
$func$;