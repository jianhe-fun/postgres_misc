/*RETURN NEXT and RETURN QUERY do not actually return from
  the function --they simply append zero or more rows
  to the function's result set.
*/
create or replace function get_2_set()
    returns setof emp
as
$$
begin
    return query
        select * from emp where empid = 8;
    return query
        select * from emp where empid = 9;
end
$$
    language plpgsql;