---
CREATE TABLE public.users (
                              id integer NOT NULL,
                              username text,
                              component_id text,
                              row_status text DEFAULT 'new'::text,
                              updated_by text
);
-- then insert some dummy data.

create or replace function update_status(
    _id_as_string text = null   --id (the intended rows) need to be updated.
    ,_status text = null) --the new values for status column
    returns text  language plpgsql as
$$
--input first parameter cast to int array. Cast to int array also reduce trailing empty spaces.
declare _ids int[] := string_to_array(_id_as_string,',')::int[];
        _updated int[];
begin
    with upd as (
        update users set row_status = _status, updated_by = 'hxBisp'
            where id = any(_ids)
            returning id)
    select array(table upd) into _updated;
    return format('Updated: %s. NOT found: %s.', _updated::text, (_ids - _updated)::text);
end
$$;