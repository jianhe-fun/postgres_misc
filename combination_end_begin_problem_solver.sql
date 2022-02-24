--https://www.postgresql.org/docs/current/arrays.html
-- https://www.postgresql.org/docs/current/functions-array.html
--https://www.postgresql.org/docs/14/plpgsql-declarations.html#PLPGSQL-DECLARATION-PARAMETERS
--https://www.postgresql.org/docs/current/functions-array.html
-- https://www.postgresql.org/docs/current/intarray.html

--problem. an ordered array, count all the combination/subset that begin with 3 end with 7.
do
$$
    declare
        _beginwith3 integer[];
        _endwith7 integer[];
        original_array integer[] := array[1,2,5,3,6,7,3,3,7,0,3,4,9,7,8];
        i integer;
        j integer;
        _count integer :=0;
    begin
        --be careful with array_position and array_positioins.
        _beginwith3 = array_positions(original_array,3);--get an new array

        _endwith7 = array_positions(original_array,7); --get an new array.

        FOREACH i IN ARRAY _beginwith3
            loop
                FOREACH j IN ARRAY  _endwith7
                    loop
                        if i < j then _count = _count + 1;
                        end if;
                    end loop;
            end loop;

        raise info '%', _count;
    end
$$;


--The fast way to solve the probelm.
do
$$
    declare
        original_array integer[] := array[1,2,5,3,6,7,3,3,7,0,3,4,9,7,8];
        result integer :=0;
        _count integer :=0;
        array_length int := array_length(original_array,1);
    begin
        FOR i IN 1..array_length LOOP
                if(original_array[i] = 3) then
                    _count = _count +1;
                elseif(original_array[i] = 7) then
                    result = result + _count;
                end if;
            END LOOP;
        raise notice '%', result;
    end
$$;











































