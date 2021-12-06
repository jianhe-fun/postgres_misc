

CREATE OR REPLACE FUNCTION f_test_array(in _colname text)
returns text as $body$
DECLARE colnames text[];
begin
colnames := ARRAY(
    SELECT column_name FROM information_schema.columns WHERE table_name='customer'
);
    if exists(select _colname = any(colnames))
    then return format('%s it exits.', _colname);
    else return format('%s not exits.', _colname);
end if;
end
$body$
LANGUAGE plpgsql;
-------------------
CREATE OR REPLACE FUNCTION f_test_array1(in _colname text)
returns text as $body$
DECLARE colnames text;
begin
colnames := (SELECT string_agg(column_name,',') FROM information_schema.columns WHERE table_name='customer')::text;
if exists(select colnames ilike '%' || quote_literal(_colname) ||'%')
    then return format('column %s  exits.', _colname);
    else return format('column %s does not exits.', _colname);
end if;
end
$body$
LANGUAGE plpgsql;


select format('select 1 %s, %%%s%%', '1','2');

select f_test_array1('first_name');







