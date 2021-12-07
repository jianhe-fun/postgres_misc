--without using declare to declare variable to return value.
--also using INOUT clause. 
CREATE OR REPLACE FUNCTION get_some_text(_param_id integer, INOUT _some_text text )
  RETURNS text AS
$func$
BEGIN
    if exists( select FROM public.parent_tree  WHERE parent_id = _param_id)
    then
        SELECT INTO _some_text  some_text FROM public.parent_tree  WHERE parent_id = _param_id;
    else 
        _some_text = 'Hello';
    end if;
END
$func$  LANGUAGE plpgsql;

