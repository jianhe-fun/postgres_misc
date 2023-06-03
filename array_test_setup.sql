
/*
        test setup for the following functions
        * array_max
        * array_min
        * array_avg
        * array_sum
        * array_median
        * array_nonull_count
*/
set extra_float_digits to 0;
drop table if exists test_generic;
create table test_generic as
select  g::int2     + (random() * 100)::int2 as a
        ,g::int4    + (random() * 100)::int4 as b
        ,g::int8    + (random() * 100)::int8 as c
        ,g::float4  + (random() * 100)::float4 as d
        ,g::float8  + (random() * 100)::float8 as e
        ,g::numeric(10,3) + (random() * 100)::numeric(10,3) as f
        ,(now() - interval '2 month')::date + (random() * 10)::int as g
        ,(now())::time(0) as h
        ,(now() - interval '2 month')::timestamp(0) + (random() * 10)::int * interval '10 hour'  as i
        ,(now() - interval '2 month')::timestamptz(0) + (random() * 10)::int * interval '10 hour' as j
        ,(interval '2 month') * (random() * 10)::int as k
        ,(now() - interval '2 month')::timetz(0) + (random() * 10)::int * interval '10 hour' as l
        ,'7/A25801C8'::pg_lsn + (random()  * 100)::numeric(10,0)      as m
from    generate_series(1,10) g;

drop table if exists test_generic_array;
create table test_generic_array as
SELECT array_agg(a) as a
        ,array_agg(b) as b
        ,array_agg(c) as c
        ,array_agg(d) as d
        ,array_agg(e) as e
        ,array_agg(f) as f
        ,array_agg(g) as g
        ,array_agg(h) as h
        ,array_agg(i) as i
        ,array_agg(j) as j
        ,array_agg(k) as k
        ,array_agg(l) as l
        ,array_agg(m) as m
from    test_generic;

--test_performance.
set extra_float_digits to 0;
drop table if exists test_generic_big;

create table test_generic_big as
select  (random() * 30000)::int2 as a
        ,g::int4    * (random() * 100)::int4 as b
        ,g::int8    * (random() * 100)::int8 as c
        ,g::float4  + (random() * 100)::float4 as d
        ,g::float8  + (random() * 100)::float8 as e
        ,g::numeric(10,3) + (random() * 100)::numeric(10,3) as f
        ,(now() - interval '2 month')::date + (random() * 10)::int as g
        ,(now())::time(0) as h
        ,(now() - interval '2 month')::timestamp(0) + (random() * 10)::int * interval '10 hour'  as i
        ,(now() - interval '2 month')::timestamptz(0) + (random() * 10)::int * interval '10 hour' as j
        ,(interval '2 month') * (random() * 10)::numeric(10,3)  as k
        ,(now() - interval '2 month')::timetz(0) + interval '10 hour' * (random() * 10)::numeric(10,3) as l
        ,'7/A25801C8'::pg_lsn + (random()  * 100)::numeric(10,3)      as m
from    generate_series(1,1e6) g;


drop table if exists test_generic_big_array;
create table test_generic_big_array as
SELECT  array_agg(a) as a
        ,array_agg(b) as b
        ,array_agg(c) as c
        ,array_agg(d) as d
        ,array_agg(e) as e
        ,array_agg(f) as f
        ,array_agg(g) as g
        ,array_agg(h) as h
        ,array_agg(i) as i
        ,array_agg(j) as j
        ,array_agg(k) as k
        ,array_agg(l) as l
        ,array_agg(m) as m
from    test_generic_big;

vacuum analyze test_generic_big_array;
vacuum analyze test_generic_big;