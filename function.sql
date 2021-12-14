--A function does represent a transaction. You do not have to wrap a function in BEGIN/COMMIT.
-- https://stackoverflow.com/questions/7622908/drop-function-without-knowing-the-number-type-of-parameters
CREATE OR REPLACE FUNCTION f_delfunc(_name text, OUT functions_dropped int)
   LANGUAGE plpgsql AS
$func$
-- drop all functions with given _name in the current search_path, 
--regardless of function parameters
DECLARE
   _sql text;
BEGIN
   SELECT count(*)::int
        , 'DROP FUNCTION ' || string_agg(oid::regprocedure::text, '; DROP FUNCTION ')
   FROM   pg_catalog.pg_proc
   WHERE  proname = _name
   AND    pg_function_is_visible(oid)  -- restrict to current search_path
   INTO   functions_dropped, _sql;     -- count only returned if subsequent DROPs succeed

   IF functions_dropped > 0 THEN       -- only if function(s) found
     EXECUTE _sql;
   END IF;
END
$func$;
-------------------------
--Loop throught an integer array demo. 
CREATE OR REPLACE FUNCTION f_array_loop()
    returns void
   LANGUAGE plpgsql AS
$func$
DECLARE
   a integer[] := array[1,2,3];
   i integer;                      -- int, not bigint
BEGIN
FOREACH i IN ARRAY a
   LOOP 
      RAISE NOTICE '%', i;
   END LOOP;
END
$func$;

--------------------
--to avoid race condition for select & insert.
CREATE FUNCTION f_tag_id(_tag_id int, _tag text, OUT _tag_id_ int, OUT _tag_ text) AS
$func$
BEGIN
LOOP
   SELECT t.tag_id, t.tag
   FROM   t
   WHERE  t.tag = _tag
   INTO   _tag_id_, _tag_;

   EXIT WHEN FOUND;  

   INSERT INTO t (tag_id, tag)
   VALUES (_tag_id, _tag)
   ON     CONFLICT (tag) DO UPDATE SET tag_id = _tag_id
   RETURNING t.tag_id, t.tag
   INTO   _tag_id_, _tag_;

   EXIT WHEN FOUND;

END LOOP;
END
$func$  LANGUAGE plpgsql;

SELECT * FROM f_tag_id(1, 'foo');
----------------------------
--return an table type result, also drop the table with on commit drop. 
--ROW_COUNT  bitint: the number of rows processed by the most recent SQL command.
CREATE OR REPLACE FUNCTION func_temp (_tbl regclass)
      RETURNS TABLE(id int, e text) AS 
   $func$
      DECLARE _ct int;
      BEGIN
         EXECUTE format(
            'create temp table tmp on commit drop as
               select parent_id, some_text from %s', _tbl
         );
         
         get diagnostics _ct = ROW_COUNT;

         RAISE NOTICE '% results', _ct;                                         
         return query table tmp;
      end
   $func$ LANGUAGE plpgsql;
---------------------
--SELECT INTO CLAUSE usage.
SELECT name,family INTO cName, cFamily FROM "CommonUsersModel";
SELECT INTO cName, cFamily name,family  FROM "CommonUsersModel" --this way also working.
SELECT  (_password = $2) INTO passed FROM _tbl WHERE _id = $1; --a little bit complicated.
---------------------------------------------------------
--to Check an text is json or not. 
create or replace function is_json(text)
returns boolean language plpgsql immutable as $$
begin
    perform $1::json;
    return true;
exception
    when invalid_text_representation then 
        return false;
end $$;

with users(user_data) as (
values
    ('{"user": {"name": "jim"}}'), ('not json'),
    ('{"user": {"name": "sally"}}'),   ('also not json')
)
select user_data::json#>'{user,name}' as name
from users where is_json(user_data);
------------------------------------------------------------
--DO block code drop all the table sharing the same prefix.
-- In this case, the table begin with 'b' will be deleted. 
DO
$do$
DECLARE
   _tbl text;
BEGIN
FOR _tbl  IN
    SELECT quote_ident(table_schema) || '.'
        || quote_ident(table_name)      -- escape identifier and schema-qualify!
    FROM   information_schema.tables
    WHERE  table_name LIKE 'b' || '%'  -- your table name prefix
    AND    table_schema NOT LIKE 'pg\_%'    -- exclude system schemas
LOOP
   RAISE NOTICE '%',
-- EXECUTE
  'DROP TABLE ' || _tbl;  -- see below
   execute 'DROP TABLE ' || _tbl || 'cascade';
END LOOP;
END
$do$;
---------------------------------------------------------------------
--Get the definition of one function with SQL query.
select pg_get_functiondef('c_foo()'::regprocedure);
--function to slice 2D array to 1D array.
CREATE OR REPLACE FUNCTION unnest_2d_1d(ANYARRAY, OUT a ANYARRAY)
  RETURNS SETOF ANYARRAY AS
$func$
BEGIN
   FOREACH a SLICE 1 IN ARRAY $1 LOOP
      RETURN NEXT;
   END LOOP;
END
$func$  LANGUAGE plpgsql IMMUTABLE STRICT;
---------------------------------------------
-- RETURN AN DEFAULT VALUE IF AN COLUMN IS NOT EXITS.
SELECT parent_id,some_text
     , CASE WHEN col_exists THEN col_exists::text ELSE 'default' END AS does_col_exists
FROM   parent_tree 
CROSS  JOIN (
   SELECT EXISTS (
      SELECT FROM pg_catalog.pg_attribute --exists don't need specify the select column name. 
      WHERE  attrelid = 'public.parent_tree'::regclass  -- schema-qualified!
      AND    attname  = 'l_tree'
      AND    NOT attisdropped    -- no dropped (dead) columns
      AND    attnum   > 0        -- no system columns
      )
   ) extra(col_exists) limit 2;
--ways to merge multi arrays into one array. Also
--get the duplicated array element.
 CREATE OR REPLACE FUNCTION mergeArrays (a2 ANYARRAY, a2 ANYARRAY)
        RETURNS ANYARRAY AS
                $$
                SELECT ARRAY_AGG(x ORDER BY x)
                FROM (SELECT DISTINCT UNNEST($2 || $2) AS x ) s;
                $$
        LANGUAGE SQL STRICT;
-------------------------------------
--EXCEPTIONS and "others" show case.
create or replace function to_timestamp_null(arg text)
returns timestamp language plpgsql
as $$
    begin
        return arg::timestamp;
    exception when others then
        return null;
    end $$;
--test time. 
select * from to_timestamp_null('foo');
--declare variable with rowtype usage.
CREATE OR REPLACE FUNCTION rowtype_test() RETURNS integer AS
$BODY$
DECLARE
    r parent_tree;
    b parent_tree[];
BEGIN
    FOR r IN SELECT * FROM parent_tree where parent_id  < 3
    LOOP
        b := b || r;
    END LOOP;
    RETURN 33;
END
$BODY$
LANGUAGE plpgsql;
-----------------
--random of random. 1. will display 1-8 random number of results. 
--2. the results will be also random integer. The integer will between 1 to 1000
CREATE OR REPLACE FUNCTION public.unique_rand_1001()
RETURNS SETOF integer AS
$body$
DECLARE
    nrnr    int := trunc(random()*7+1);  -- number of numbers
BEGIN

    RETURN QUERY
    SELECT (1000 * random())::integer + 1
    FROM   generate_series(1, nrnr*2)
    GROUP  BY 1 -- to reduce the duplicted result. 
    LIMIT  nrnr; -- get the random number of numbers.
END;
$body$ LANGUAGE plpgsql VOLATILE;
----------------------
