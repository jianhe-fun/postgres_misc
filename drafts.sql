

--- distinct with generate_series.
SELECT distinct(some_text), generate_series(1, 2) AS index FROM  parent_tree order by 1;
\df !~ dblink




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
   ON     CONFLICT (tag) DO NOTHING
   RETURNING t.tag_id, t.tag
   INTO   _tag_id_, _tag_;

   EXIT WHEN FOUND;
END LOOP;
END
$func$  LANGUAGE plpgsql;