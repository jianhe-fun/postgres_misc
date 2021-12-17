--genreral format of IF clause in plpgsql
BEGIN
  IF EXISTS(SELECT name FROM test_table t   WHERE t.id = x AND t.name = 'test')
  THEN
     ---
  ELSE
     ---
  END IF;
end
-----FORMAT FOR LOOP.
-- https://www.postgresql.org/docs/14/plpgsql-declarations.html#PLPGSQL-DECLARATION-RECORDS
/*

   Record variables are similar to row-type variables, but they have no predefined structure. 
-- They take on the actual row structure of the row they are assigned during a SELECT or FOR command. 
-- The substructure of a record variable can change each time it is assigned to. 
-- A consequence of this is that until a record variable is first assigned to, it has no substructure, 
-- and any attempt to access a field in it will draw a run-time error.

*/
CREATE OR REPLACE FUNCTION avoidable_states()
  RETURNS SETOF varchar AS
$func$
DECLARE
    rec record;
BEGIN   
   FOR rec IN
      SELECT *
      FROM   address ad
      JOIN   city    ct USING (city_id)
   LOOP
      IF rec.city LIKE '%hi%' THEN
          RETURN NEXT rec.city;               
      END IF;
   END LOOP;
END
$func$  LANGUAGE plpgsql STABLE;
-----------------------------
--General format for LOOP and incremental in plpgsql function body.
DECLARE
   iterator float4 := 1;  -- we can init at declaration time
BEGIN
   WHILE iterator < 999
   LOOP
      iterator := iterator + 1;
      -- do stuff
   END LOOP;
END;
-----------
--General fromat for get the data modifying data.
$$
DECLARE array_var BIGINT[];
BEGIN
  WITH updated(found_id) AS (
    UPDATE child SET foo=bar RETURNING id
  )
  SELECT array_agg(found_id) FROM updated INTO array_var;
END
$$
---------------------------
--for loop, implicit cursor. format.
CREATE OR REPLACE FUNCTION f_curs2(_tbl text)
  RETURNS void AS
$func$
DECLARE
   _ctid tid;
BEGIN
   FOR _ctid IN EXECUTE 'SELECT ctid FROM ' || quote_ident(_tbl) FOR UPDATE
   LOOP
      EXECUTE format('UPDATE %I SET tbl_id = tbl_id + 100 WHERE ctid = $1', _tbl)
      USING _ctid;
   END LOOP;
END
$func$  LANGUAGE plpgsql;
-----------------------------------------------------
-- DO Block format. 
--1. set up the function
CREATE OR REPLACE FUNCTION pg_temp_3.columnvaluetolower(_tbl regclass, _col text)                                                2  RETURNS void
      LANGUAGE plpgsql
     AS $function$
             BEGIN
             execute format('update %s set %I = lower(%I)',_tbl,_col,_col);
             END
     $function$
--2. dymatic execute the user defined function.
DO
$do$
DECLARE
   _tbl text;
BEGIN
PERFORM pg_temp.columnvaluetolower('parent_tree', t.val) 
   FROM   (VALUES ('some_text')) t(val);
END
$do$;
-----------------------------------------------
--general format for profile and test the time consumed about executing the
--function.
DECLARE
start_time timestamp:= clock_timestamp();
end_time timestamp := clock_timestamp();
BEGIN
  raise info 'start time:  %', start_time;
  FOR r IN SELECT * FROM parent_tree
  LOOP
    RAISE NOTICE '%', r.parent_id; 
  END LOOP;
raise info 'ending time %', end_time;
END
-----------------------------------------
--create a temp table based on other query string.
EXECUTE '
CREATE TEMP TABLE query_result ON COMMIT DROP AS '|| query_string_;
---
