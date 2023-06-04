/*
    array_min function setup. and some benchmark.
*/
begin;
      --anyarray should be any one dimension array.
	CREATE OR REPLACE FUNCTION array_nonull_count(anyarray)
	RETURNS bigint SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_nonull_count', 'array_nonull_count'
	LANGUAGE c IMMUTABLE STRICT;
commit;

select array_nonull_count('{1,2,3,4,5,null,null}'::int8[])
		,array_nonull_count('{1,2,3,4,5,null,null}'::int4[])
		,array_nonull_count('{1,2,3,4,5,null,null}'::int2[])
		,array_nonull_count('{1,2,3,4,5,null,null}'::numeric[]);
/*
 array_nonull_count | array_nonull_count | array_nonull_count | array_nonull_count
--------------------+--------------------+--------------------+--------------------
                  5 |                  5 |                  5 |                  5
(1 row)
*/
\gdesc
/*
       Column       |  Type
--------------------+--------
 array_nonull_count | bigint
 array_nonull_count | bigint
 array_nonull_count | bigint
 array_nonull_count | bigint
(4 rows)
*/

select  array_nonull_count('{null,NULL,NULL}'::int2[])
		,array_nonull_count('{null,NULL,NULL}'::int4[])
		,array_nonull_count('{null,NULL,NULL}'::int8[])
		,array_nonull_count('{null,NULL,NULL}'::numeric[]);
/*
 array_nonull_count | array_nonull_count | array_nonull_count | array_nonull_count
--------------------+--------------------+--------------------+--------------------
                    |                    |                    |
(1 row)
*/ 
select array_nonull_count('{}'::int2[]);     
select array_nonull_count('{}'::int4[]);     
select array_nonull_count('{}'::int8[]);     
select array_nonull_count('{}'::numeric[]);     


select	array_nonull_count(null::int4[])
		,array_nonull_count(null::numeric[])
		,array_nonull_count(null::int8[])
		,array_nonull_count(null::int2[]);
/*
 array_nonull_count | array_nonull_count | array_nonull_count | array_nonull_count
--------------------+--------------------+--------------------+--------------------
                    |                    |                    |
(1 row)

*/

select array_nonull_count(k) from test_generic_array;
/*
 array_nonull_count
--------------------
                 10
(1 row)
*/

select array_nonull_count('{1s,2s,3s,4s,5s,null,null}'::interval[]);
/*
 array_nonull_count
--------------------
                  5
(1 row)
*/

-------------------------------------------------------------------------------------------
--performance test
-------------------------------------------------------------------------------------------
--validate result first.

(select count(a) as a,count(b) as b,count(c) as c,count(f) as f,count(k) as k from test_generic_big   )
EXCEPT 
(select  array_nonull_count(a) as a,array_nonull_count(b) as b,array_nonull_count(c) as c, array_nonull_count(f) as f, array_nonull_count(k) as k 
from test_generic_big_array);
/*
 a | b | c | f | k
---+---+---+---+---
(0 rows)
*/

explain(analyze, buffers,costs off)
select  count(a) as a
        ,count(b) as b
        ,count(c) as c
        ,count(f) as f
        ,count(k) as k
from    test_generic_big \watch c=3    
/*
                                                QUERY PLAN
----------------------------------------------------------------------------------------------------------
 Finalize Aggregate (actual time=1095.136..1110.333 rows=1 loops=1)
   Buffers: shared hit=224 read=17018
   ->  Gather (actual time=1094.840..1110.315 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=224 read=17018
         ->  Partial Aggregate (actual time=1084.754..1084.755 rows=1 loops=3)
               Buffers: shared hit=224 read=17018
               ->  Parallel Seq Scan on test_generic_big (actual time=0.047..288.542 rows=333333 loops=3)
                     Buffers: shared hit=224 read=17018
 Planning Time: 0.466 ms
 Execution Time: 1110.650 ms
(12 rows)
*/

explain(analyze, buffers,costs off)
select 
    array_nonull_count(a) as a
    ,array_nonull_count(b) as b
    ,array_nonull_count(c) as c
    ,array_nonull_count(f) as f
    ,array_nonull_count(k) as k
from test_generic_big_array \watch c=3
/*
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual time=372.933..378.611 rows=1 loops=1)
   Buffers: shared hit=2550
 Planning Time: 0.162 ms
 Execution Time: 378.699 ms
(4 rows)
*/

explain(analyze, buffers,costs off)
select * from
    (select count(a.a) as a from test_generic_big_array,unnest(a) a) sub
    ,
    (select  count(b.b) as b from test_generic_big_array ,unnest(b) b) sub1 \watch c=3
/*

                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Nested Loop (actual time=5254.178..5254.184 rows=1 loops=1)
   Buffers: shared hit=766, temp read=3174 written=3174
   ->  Aggregate (actual time=2622.084..2622.087 rows=1 loops=1)
         Buffers: shared hit=256, temp read=1465 written=1465
         ->  Nested Loop (actual time=887.385..2222.380 rows=1000000 loops=1)
               Buffers: shared hit=256, temp read=1465 written=1465
               ->  Seq Scan on test_generic_big_array (actual time=0.012..0.018 rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest a (actual time=887.364..1663.865 rows=1000000 loops=1)
                     Buffers: shared hit=255, temp read=1465 written=1465
   ->  Aggregate (actual time=2632.089..2632.091 rows=1 loops=1)
         Buffers: shared hit=510, temp read=1709 written=1709
         ->  Nested Loop (actual time=894.721..2231.735 rows=1000000 loops=1)
               Buffers: shared hit=510, temp read=1709 written=1709
               ->  Seq Scan on test_generic_big_array test_generic_big_array_1 (actual time=0.013..0.019 rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest b (actual time=894.700..1673.670 rows=1000000 loops=1)
                     Buffers: shared hit=509, temp read=1709 written=1709
 Planning Time: 0.311 ms
 Execution Time: 5267.814 ms
(20 rows)
*/

explain(analyze, buffers,costs off)
select array_nonull_count(a) as a ,array_nonull_count(b) as b
from test_generic_big_array \watch c=3
/*
                                    QUERY PLAN
----------------------------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual time=123.947..124.831 rows=1 loops=1)
   Buffers: shared hit=765
 Planning Time: 0.125 ms
 Execution Time: 124.900 ms
(4 rows)
*/

explain(analyze, buffers,costs off)
select  count(a) as a
from    test_generic_big \watch c=3  
/*
                                                QUERY PLAN
----------------------------------------------------------------------------------------------------------
 Finalize Aggregate (actual time=556.087..573.658 rows=1 loops=1)
   Buffers: shared hit=512 read=16730
   ->  Gather (actual time=555.859..573.645 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=512 read=16730
         ->  Partial Aggregate (actual time=545.956..545.957 rows=1 loops=3)
               Buffers: shared hit=512 read=16730
               ->  Parallel Seq Scan on test_generic_big (actual time=0.051..287.488 rows=333333 loops=3)
                     Buffers: shared hit=512 read=16730
 Planning Time: 0.239 ms
 Execution Time: 573.836 ms
(12 rows)

*/

explain(analyze, buffers,costs off)
select array_nonull_count(a) as a
from test_generic_big_array \watch c=3
/*
                                   QUERY PLAN
--------------------------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual time=60.341..60.749 rows=1 loops=1)
   Buffers: shared hit=256
 Planning Time: 0.118 ms
 Execution Time: 60.811 ms
(4 rows)
*/