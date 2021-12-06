-- Store query result in a variable using in PL/pgSQL

CREATE OR REPLACE FUNCTION test_query_variable(x numeric)
RETURNS character varying AS
$BODY$
DECLARE
name   character varying(255);
begin
--1. select into caluse.
--select customer_list.name into name from customer_list where id = x;

-- 2.---
name := (SELECT t.name from customer_list t where t.id = x);
if name is not null  
    then return format('%s does exists', name);
else return 'name does not exists';
end if;

end;
$BODY$
LANGUAGE plpgsql VOLATILE;