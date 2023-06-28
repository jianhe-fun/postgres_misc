/*
    array_min function setup. and some benchmark.
*/
begin;
      --anyarray should be any one dimension array.
	CREATE OR REPLACE FUNCTION array_nonull_count(anyarray)
	RETURNS bigint SET search_path from current
	AS '/home/jian/postgres_misc/array_nonull_count', 'array_nonull_count'
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

explain(analyze, buffers,costs off,timing off)
select 
      array_nonull_count(array_agg(a)) as a
      ,array_nonull_count(array_agg(b)) as b
      ,array_nonull_count(array_agg(c)) as c
      ,array_nonull_count(array_agg(f)) as f
      ,array_nonull_count(array_agg(k)) as k                            
from  test_generic_big
where (a is not null and b is not null and c is not null and f is not null and k is not null) \watch c=3

/*
                                                    QUERY PLAN
-------------------------------------------------------------------------------------------------------------------
 Aggregate (actual rows=1 loops=1)
   Buffers: shared hit=704 read=16538
   ->  Seq Scan on test_generic_big (actual rows=1000000 loops=1)
         Filter: ((a IS NOT NULL) AND (b IS NOT NULL) AND (c IS NOT NULL) AND (f IS NOT NULL) AND (k IS NOT NULL))
         Buffers: shared hit=704 read=16538
 Planning Time: 0.204 ms
 Execution Time: 5008.303 ms
(7 rows)
*/

explain(analyze, buffers,costs off,timing off)
select count(a) as a, count(b) as b, count(c) as c, count(f) as f, count(k) as k
from  test_generic_big  \watch c=3
/*
                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Finalize Aggregate (actual rows=1 loops=1)
   Buffers: shared hit=928 read=16314
   ->  Gather (actual rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=928 read=16314
         ->  Partial Aggregate (actual rows=1 loops=3)
               Buffers: shared hit=928 read=16314
               ->  Parallel Seq Scan on test_generic_big (actual rows=333333 loops=3)
                     Buffers: shared hit=928 read=16314
 Planning Time: 0.531 ms
 Execution Time: 1070.984 ms
(12 rows)
*/

explain(analyze, buffers,costs off, timing off)
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

explain(analyze, buffers,costs off,timing off)
select * from
    (select count(a.a) as a from test_generic_big_array,unnest(a) a) sub
    ,
    (select  count(b.b) as b from test_generic_big_array ,unnest(b) b) sub1 \watch c=3
/*
                                              QUERY PLAN
-------------------------------------------------------------------------------------------------------
 Nested Loop (actual rows=1 loops=1)
   Buffers: shared hit=766, temp read=3174 written=3174
   ->  Aggregate (actual rows=1 loops=1)
         Buffers: shared hit=256, temp read=1465 written=1465
         ->  Nested Loop (actual rows=1000000 loops=1)
               Buffers: shared hit=256, temp read=1465 written=1465
               ->  Seq Scan on test_generic_big_array (actual rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest a (actual rows=1000000 loops=1)
                     Buffers: shared hit=255, temp read=1465 written=1465
   ->  Aggregate (actual rows=1 loops=1)
         Buffers: shared hit=510, temp read=1709 written=1709
         ->  Nested Loop (actual rows=1000000 loops=1)
               Buffers: shared hit=510, temp read=1709 written=1709
               ->  Seq Scan on test_generic_big_array test_generic_big_array_1 (actual rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest b (actual rows=1000000 loops=1)
                     Buffers: shared hit=509, temp read=1709 written=1709
 Planning Time: 0.308 ms
 Execution Time: 4952.178 ms
(20 rows)
*/

explain(analyze, buffers,costs off,timing off)
select array_nonull_count(a) as a ,array_nonull_count(b) as b
from test_generic_big_array \watch c=3
/*
                         QUERY PLAN
------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual rows=1 loops=1)
   Buffers: shared hit=765
 Planning Time: 0.122 ms
 Execution Time: 123.185 ms
(4 rows)
*/

explain(analyze, buffers,costs off,timing off)
select  count(a) as a
from    test_generic_big \watch c=3  
/*
                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Finalize Aggregate (actual rows=1 loops=1)
   Buffers: shared hit=1216 read=16026
   ->  Gather (actual rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=1216 read=16026
         ->  Partial Aggregate (actual rows=1 loops=3)
               Buffers: shared hit=1216 read=16026
               ->  Parallel Seq Scan on test_generic_big (actual rows=333333 loops=3)
                     Buffers: shared hit=1216 read=16026
 Planning Time: 0.261 ms
 Execution Time: 533.289 ms
(12 rows)
*/

explain(analyze, buffers,costs off, timing off)
select array_nonull_count(a) as a
from test_generic_big_array \watch c=3
/*
                         QUERY PLAN
------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual rows=1 loops=1)
   Buffers: shared hit=256
 Planning Time: 0.110 ms
 Execution Time: 61.007 ms
(4 rows)
*/