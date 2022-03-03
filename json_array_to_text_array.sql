
--data init.
begin;
create table jsonb_test(
    tbl_id bigint primary key,
    data json
);
INSERT INTO jsonb_test VALUES
   (1, '{"name": "test1", "tags": ["foo", "bar","baz"]}')
 , (2, '{"name": "empty", "tags": [null]}')  -- null element
 , (3, '{"name": "empty", "tags": []}')      -- empty array
 , (4, '{"name": "none"}');
commit;


--json array to text array function
create or replace function
    json_arr2text_arr(_js json)
returns text[] language sql immutable parallel safe
as
'select array(select json_array_elements_text(_js))';

--with custom array function.
select tbl_id,
       json_arr2text_arr(j.data->'tags') as txt_arr
from jsonb_test j;