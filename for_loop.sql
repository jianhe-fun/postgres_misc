--test is a label.
--x will be the same, but y will be from -x (int) to (x-1 )(int).
create or replace function
    public.generate_terrain_simple_1(_outer int)
    returns void as $$
declare _x int; _y int;
begin
    <<test>>
    for _x, _y in
        select -_outer, g from generate_series(-_outer,_outer - 1) g
        loop
            raise info 'test % %', _x,_y;
        end loop test;
end
$$ language plpgsql;
--
select * from generate_terrain_simple_1(4);