/*
    array_sum function setup. and some benchmark.
*/
begin;
	drop FUNCTION if exists array_sum(int8[]);
	drop FUNCTION if exists array_sum(int4[]);
	drop FUNCTION if exists array_sum(int2[]);
	drop FUNCTION if exists array_sum(numeric[]);
	drop FUNCTION if exists array_sum(float4[]);
	drop FUNCTION if exists array_sum(float8[]);
	drop FUNCTION if exists array_sum(interval[]);

	CREATE OR REPLACE FUNCTION array_sum(int8[])
	RETURNS numeric SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_sum', 'array_sum'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_sum(int2[])
	RETURNS bigint SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_sum', 'array_sum'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_sum(int4[])
	RETURNS bigint SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_sum', 'array_sum'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_sum(numeric[])
	RETURNS numeric SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_sum', 'array_sum'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_sum(float4[])
	RETURNS float4 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_sum', 'array_sum'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_sum(float8[])
	RETURNS float8 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_sum', 'array_sum'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_sum(interval[])
	RETURNS interval SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_sum', 'array_sum'
	LANGUAGE c IMMUTABLE STRICT;
commit;

set extra_float_digits to 0;
--special case test 
select  array_sum('{1,2,3,4,5,null,null}'::int8[])
        ,array_sum('{1,2,3,4,5,null,null}'::int4[])
        ,array_sum('{1,2,3,4,5,null,null}'::int2[])
        ,array_sum('{1,2,3,4,5,null,null}'::numeric[]);

select array_sum('{null,NULL,NULL}'::int2[])
        ,array_sum('{null,NULL,NULL}'::numeric[])
        ,array_sum('{null,NULL,NULL}'::int8[])
        ,array_sum('{null,NULL,NULL}'::int4[]);

select array_sum(null::int2[]),array_sum(null::int4[]), array_sum(null::int8[]),array_sum(null::numeric[]);

select array_sum('{}'::int4[]);     
select array_sum('{}'::int8[]);     
select array_sum('{}'::numeric[]);     
select array_sum('{}'::int2[]);     

--validate result.
(   
    select sum(a) as a,sum(b) as b,sum(c) as c,sum(d) as d,sum(e) as e,sum(f) as f,sum(k) as k
    from test_generic
)
EXCEPT
select array_sum(a) as a,array_sum(b) as b,array_sum(c) as c,array_sum(d) as d,array_sum(e) as e
    ,array_sum(f) as f
    ,array_sum(k) as k
from test_generic_array;
/*
 a | b | c | d | e | f | k
---+---+---+---+---+---+---
(0 rows)
*/
 
-------------------------------------------------------------------------------------------
--performance test
-------------------------------------------------------------------------------------------

--validate result first.
(select sum(a) as a,sum(b) as b,sum(c) as c,sum(f) as f,sum(k) as k from test_generic_big   )
EXCEPT 
(
    select  array_sum(a) as a,array_sum(b) as b,array_sum(c) as c, array_sum(f) as f, array_sum(k) as k 
    from test_generic_big_array
);
/*
 a | b | c | f | k
---+---+---+---+---
(0 rows)
*/

select x as native_float4_sum ,y as float4_pl, x - y as float4_diff
from
    (select sum(d) from test_generic_big) x(x)
    ,(select array_sum(d) from test_generic_big_array) y(y);
/*
 native_float4_sum |  float4_pl  | float4_diff
-------------------+-------------+-------------
       5.00075e+11 | 4.99893e+11 | 1.81469e+08
(1 row)
*/

select x as native_float8_sum,y as float8_pl, x - y as float8_diff
from
    (select sum(e) from test_generic_big) x(x)
    ,(select array_sum(e) from test_generic_big_array) y(y);
/*
 native_float8_sum |    float8_pl    |   float8_diff
-------------------+-----------------+------------------
  500050482544.676 | 500050482544.67 | 0.00604248046875
(1 row)
*/

explain(analyze, buffers,costs off)
select  sum(a) as a
        ,sum(b) as b
        ,sum(c) as c
        ,sum(f) as f
        ,sum(k) as k
from    test_generic_big \watch c=3                      
/*
                                                QUERY PLAN
----------------------------------------------------------------------------------------------------------
 Finalize Aggregate (actual time=1713.528..1725.895 rows=1 loops=1)
   Buffers: shared hit=2688 read=14554
   ->  Gather (actual time=1713.359..1725.824 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=2688 read=14554
         ->  Partial Aggregate (actual time=1696.429..1696.431 rows=1 loops=3)
               Buffers: shared hit=2688 read=14554
               ->  Parallel Seq Scan on test_generic_big (actual time=0.044..293.722 rows=333333 loops=3)
                     Buffers: shared hit=2688 read=14554
 Planning Time: 0.441 ms
 Execution Time: 1726.203 ms
(12 rows)
*/

explain(analyze, buffers,costs off)
select 
    array_sum(a) as a
    ,array_sum(b) as b
    ,array_sum(c) as c
    ,array_sum(f) as f
    ,array_sum(k) as k
from test_generic_big_array \watch c=3
/*
                                     QUERY PLAN
------------------------------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual time=3152.613..3504.837 rows=1 loops=1)
   Buffers: shared hit=2550
 Planning Time: 0.075 ms
 Execution Time: 3504.889 ms
(4 rows)
*/

explain(analyze, buffers,costs off)
select * from
    (select sum(a.a) as a from test_generic_big_array,unnest(a) a) sub
    ,
    (select  sum(b.b) as b from test_generic_big_array ,unnest(b) b) sub1 \watch c=3
/*
                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Nested Loop (actual time=5208.917..5208.922 rows=1 loops=1)
   Buffers: shared hit=766, temp read=3174 written=3174
   ->  Aggregate (actual time=2604.741..2604.743 rows=1 loops=1)
         Buffers: shared hit=256, temp read=1465 written=1465
         ->  Nested Loop (actual time=891.451..2231.500 rows=1000000 loops=1)
               Buffers: shared hit=256, temp read=1465 written=1465
               ->  Seq Scan on test_generic_big_array (actual time=0.012..0.020 rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest a (actual time=891.431..1673.095 rows=1000000 loops=1)
                     Buffers: shared hit=255, temp read=1465 written=1465
   ->  Aggregate (actual time=2604.171..2604.172 rows=1 loops=1)
         Buffers: shared hit=510, temp read=1709 written=1709
         ->  Nested Loop (actual time=892.439..2227.021 rows=1000000 loops=1)
               Buffers: shared hit=510, temp read=1709 written=1709
               ->  Seq Scan on test_generic_big_array test_generic_big_array_1 (actual time=0.013..0.019 rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest b (actual time=892.419..1669.303 rows=1000000 loops=1)
                     Buffers: shared hit=509, temp read=1709 written=1709
 Planning Time: 0.306 ms
 Execution Time: 5228.577 ms
(20 rows)
*/

explain(analyze, buffers,costs off)
select array_sum(a) as a ,array_sum(b) as b
from test_generic_big_array \watch c=3
/*
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual time=269.876..270.779 rows=1 loops=1)
   Buffers: shared hit=765
 Planning Time: 0.124 ms
 Execution Time: 270.848 ms
(4 rows)
*/