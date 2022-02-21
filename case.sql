--------------
--select statement with case expression.
create or replace function test_123(n integer)
    returns table(_placeholder1 text, _placeholder2 text) as
$func$
begin
    case n
        when 1 then return query select e.name,e.department::text  from emp e;
        when 2 then return query select e.empid::text,e.misc::text from emp e;
        when 3 then return query select  e.empid::text, e.salary::text from emp e;
        end case;
end;
$func$ language plpgsql;

select * from test_123(1)