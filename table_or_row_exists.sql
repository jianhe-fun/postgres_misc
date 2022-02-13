--check if table exits, if not then that's it, otherwise insert records to table. 
DO
$$
    BEGIN
        if not exists(select from orders) then
            delete from orders;
        else
            insert into orders values ('20220213010','2022-02-13', '0003');
        end if;
end
$$

----row exists.

if exists (select from orders o where o.order_num = my_customize_no) then ...

---intrincially check if table exists or not. 
--if not, it will automatically fail.
create or replace function table_exists(_tbl regclass, out result text)
as
$$
    declare is_true int;
    BEGIN
        execute format('select (exists (select from %s))::int', _tbl) into is_true;
        if is_true = 1 then result := 'table exists';
        else result := 'table not exists';
        end if;
    end
$$
language plpgsql;

--demo
select table_exists('public.orders');

