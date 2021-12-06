
CREATE OR REPLACE FUNCTION func_table_as_p(_tbl regclass, OUT result integer)
    LANGUAGE plpgsql AS
$func$
BEGIN
   EXECUTE format('SELECT (EXISTS (SELECT FROM %s WHERE actor_id = 1))::int', _tbl)
   INTO result;
END
$func$;

select func_table_as_p('actor'); --working
select func_table_as_p('public.actor'); --working. 



CREATE OR REPLACE FUNCTION f_tbl_value(_tbl text, _schema text = 'public')
  RETURNS TABLE (value text) AS
$func$
DECLARE
   _t regclass := to_regclass(_schema || '.' || _tbl);
BEGIN
   IF _t IS NULL THEN
      value := ''; RETURN NEXT;    -- return single empty string
   ELSE
      RETURN QUERY EXECUTE format
      ('SELECT value FROM %s', _t);  -- return set of values
   END
$func$ LANGUAGE plpgsql;

-- EXECUTE format('SELECT (EXISTS (SELECT FROM %s WHERE id = 1))::int', _tbl)