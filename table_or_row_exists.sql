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
