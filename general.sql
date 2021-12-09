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
------------
