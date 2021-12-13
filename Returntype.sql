--About return type.
/*
match the return data type.
1.  setof  RETURNS SETOF my_table AS
2. table  RETURNS TABLE (COLA INT, COLB INT,....)
3. Record, return full row type.  RETURN SETOF RECORD AS
*/
--Create demo table.
begin;
CREATE TYPE public.ltree AS (a int, b int);
CREATE TABLE public.parent_tree(parent_id int, l_tree ltree, some_text text);
INSERT INTO public.parent_tree VALUES
  (1, (2,2), 'a')
, (2, (1,2), 'b')
, (3, (1,7), 'c');
TABLE parent_tree;
commit;

-- doesn't work:
CREATE OR REPLACE FUNCTION public.get_parent_ltree (IN  _parent_id int
                                                  , OUT _l_tree    ltree
                                                  , OUT _some_text text)
  LANGUAGE plpgsql AS
$func$
BEGIN
   SELECT l_tree, some_text FROM public.parent_tree WHERE parent_id = _parent_id
   INTO  _l_tree, _some_text;
END
$func$;
-- ERROR:  record variable cannot be part of multiple-item INTO list
-- LINE 8:    INTO  _l_tree, _some_text;

-- doesn't work:
CREATE OR REPLACE FUNCTION public.get_parent_ltree1 (IN  _parent_id int
                                                   , OUT _l_tree    ltree
                                                   , OUT _some_text text)
  LANGUAGE plpgsql AS
$func$
BEGIN
   SELECT (l_tree).*, some_text FROM public.parent_tree WHERE parent_id = _parent_id
   INTO  _l_tree, _some_text;
END
$func$;
-- ERROR:  record variable cannot be part of multiple-item INTO list
-- LINE 8:    INTO  _l_tree, _some_text;

-- doesn't work:
CREATE OR REPLACE FUNCTION public.get_parent_ltree2 (IN  _parent_id int
                                                   , OUT _l_tree    ltree
                                                   , OUT _some_text text)
  LANGUAGE plpgsql AS
$func$
BEGIN
   SELECT (l_tree).a, (l_tree).b, some_text FROM public.parent_tree WHERE parent_id = _parent_id
   INTO  _l_tree, _some_text;
END
$func$;
-- ERROR:  record variable cannot be part of multiple-item INTO list
-- LINE 8:    INTO  _l_tree, _some_text;

--- works!
CREATE OR REPLACE FUNCTION public.get_parent_ltree3 (_parent_id int)
  RETURNS TABLE (_l_tree ltree, _some_text text)
  LANGUAGE plpgsql AS
$func$
BEGIN
   RETURN QUERY
   SELECT l_tree, some_text FROM public.parent_tree WHERE parent_id = _parent_id;
END
$func$;

--- works!!!
CREATE OR REPLACE FUNCTION public.get_parent_ltree4 (IN  _parent_id int
                                                   , OUT _l_tree    ltree
                                                   , OUT _some_text text)
  RETURNS SETOF record
  LANGUAGE plpgsql AS
$func$
BEGIN
   RETURN QUERY
   SELECT l_tree, some_text FROM public.parent_tree WHERE parent_id = _parent_id;
END
$func$;

--in case, you want to select all the columns.
--pg_typeof is declared as returning regtype, which is an OID alias type. 
--format %s >> s formats the argument value as a simple string. A null value is treated as an empty string
--regtype automatically double quoted and schema-qualified. 
CREATE OR REPLACE FUNCTION public.get_parent_ltree5(_tbl_type anyelement, _parent_id int)
  returns setof anyelement
  language plpgsql as 
  $func$
  begin
    return query execute format('
    select * from %s --pg_typeof returns regtype, quoted automatically.
    where  parent_id = $1'
    ,pg_typeof(_tbl_type))
    using _parent_id;
  end
  $func$;
--Now call get_parent_ltree5 by followin:
select * from get_parent_ltree5(null::parent_tree, 1);

--Table as function input parameter.
CREATE OR REPLACE FUNCTION update_id(_tbl regclass)
  RETURNS void AS
$func$
BEGIN
   EXECUTE format('UPDATE %s SET parent_id = parent_id + 1', _tbl);
END
$func$  LANGUAGE plpgsql;
--because the regclass parameter is automatically properly escaped when (automatically) converted to text.
--%s is OK for here. But if _tbl type is text then we need to using %I to convert it to regclass


