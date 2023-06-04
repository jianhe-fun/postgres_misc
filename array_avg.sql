begin;
      drop function if exists array_avg(int2[]);
      drop function if exists array_avg(int4[]);
      drop function if exists array_avg(int8[]);
      drop function if exists array_avg(numeric[]);

	CREATE OR REPLACE FUNCTION array_avg(int2[])
	RETURNS numeric SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_avg', 'array_avg'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_avg(int4[])
	RETURNS numeric SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_avg', 'array_avg'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_avg(int8[])
	RETURNS numeric SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_avg', 'array_avg'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_avg(numeric[])
	RETURNS numeric SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_avg', 'array_avg'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_avg(interval[])
	RETURNS interval SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_avg', 'array_avg'
	LANGUAGE c IMMUTABLE STRICT;
commit;


select array_avg('{1,2,3,4,5,null,null}'::int8[])
      ,array_avg('{1,2,3,4,5,null,null}'::int4[])
      ,array_avg('{1,2,3,4,5,null,null}'::int2[])
      ,array_avg('{1,2,3,4,5,null,null}'::numeric[])
      ,array_avg('{1s,2s,3s,4s,5s,null,null}'::interval[]);

select  array_avg('{null,NULL,NULL}'::int2[])
        ,array_avg('{null,NULL,NULL}'::int4[])
        ,array_avg('{null,NULL,NULL}'::int8[])
        ,array_avg('{null,NULL,NULL}'::numeric[]);

select array_avg(null::int8[]),array_avg(null::numeric[]),array_avg(null::int4[]),array_avg(null::int2[]);

select array_avg('{}'::int8[]);     
select array_avg('{}'::numeric[]);     
select array_avg('{}'::int4[]);     
select array_avg('{}'::int2[]);     

--validate
(   
    select avg(a) as a,avg(b) as b,avg(c) as c,avg(f) as f,avg(k) as k
    from test_generic
)
EXCEPT
select array_avg(a) as a,array_avg(b) as b,array_avg(c) as c
    ,array_avg(f) as f
    ,array_avg(k) as k
from test_generic_array;


-------------------------------------------------------------------------------------------
--performance test
-------------------------------------------------------------------------------------------
--validate result first.
(select avg(a) as a,avg(b) as b,avg(c) as c,avg(f) as f,avg(k) as k from test_generic_big   )
EXCEPT 
(select  array_avg(a) as a,array_avg(b) as b,array_avg(c) as c, array_avg(f) as f, array_avg(k) as k 
from test_generic_big_array);


explain(analyze, buffers,costs off)
select  avg(a) as a
        ,avg(b) as b
        ,avg(c) as c
        ,avg(f) as f
        ,avg(k) as k
from    test_generic_big \watch c=3     
/*
                                                QUERY PLAN
----------------------------------------------------------------------------------------------------------
 Finalize Aggregate (actual time=2351.591..2369.598 rows=1 loops=1)
   Buffers: shared hit=3744 read=13498
   ->  Gather (actual time=2351.524..2369.539 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=3744 read=13498
         ->  Partial Aggregate (actual time=2341.951..2341.952 rows=1 loops=3)
               Buffers: shared hit=3744 read=13498
               ->  Parallel Seq Scan on test_generic_big (actual time=0.025..286.677 rows=333333 loops=3)
                     Buffers: shared hit=3744 read=13498
 Planning Time: 0.223 ms
 Execution Time: 2369.806 ms
(12 rows)
*/

explain(analyze, buffers,costs off)
select 
    array_avg(a) as a
    ,array_avg(b) as b
    ,array_avg(c) as c
    ,array_avg(f) as f
    ,array_avg(k) as k
from test_generic_big_array \watch c=3
/*
                                     QUERY PLAN
------------------------------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual time=6023.759..6737.916 rows=1 loops=1)
   Buffers: shared hit=2550
 Planning Time: 0.078 ms
 Execution Time: 6737.967 ms
(4 rows)
*/

------------------------------------------------------------------------------------
explain(analyze, buffers,costs off)
select * from
    (select avg(a.a) as a from test_generic_big_array,unnest(a) a) sub
    ,
    (select  avg(b.b) as b from test_generic_big_array ,unnest(b) b) sub1 \watch c=3
/*

                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Nested Loop (actual time=5360.209..5360.214 rows=1 loops=1)
   Buffers: shared hit=766, temp read=3174 written=3174
   ->  Aggregate (actual time=2683.191..2683.194 rows=1 loops=1)
         Buffers: shared hit=256, temp read=1465 written=1465
         ->  Nested Loop (actual time=885.807..2222.085 rows=1000000 loops=1)
               Buffers: shared hit=256, temp read=1465 written=1465
               ->  Seq Scan on test_generic_big_array (actual time=0.011..0.017 rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest a (actual time=885.789..1663.174 rows=1000000 loops=1)
                     Buffers: shared hit=255, temp read=1465 written=1465
   ->  Aggregate (actual time=2677.013..2677.014 rows=1 loops=1)
         Buffers: shared hit=510, temp read=1709 written=1709
         ->  Nested Loop (actual time=886.509..2220.186 rows=1000000 loops=1)
               Buffers: shared hit=510, temp read=1709 written=1709
               ->  Seq Scan on test_generic_big_array test_generic_big_array_1 (actual time=0.014..0.020 rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest b (actual time=886.488..1663.193 rows=1000000 loops=1)
                     Buffers: shared hit=509, temp read=1709 written=1709
 Planning Time: 0.322 ms
 Execution Time: 5374.315 ms
(20 rows)
*/

explain(analyze, buffers,costs off)
select array_avg(a) as a ,array_avg(b) as b
from test_generic_big_array \watch c=3
/*
                                     QUERY PLAN
------------------------------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual time=3131.723..3492.046 rows=1 loops=1)
   Buffers: shared hit=765
 Planning Time: 0.060 ms
 Execution Time: 3492.087 ms
(4 rows)
*/

------------------------------------------------------------------------------------

explain(analyze, buffers,costs off)
select  avg(a) as a
from    test_generic_big \watch c=3  
/*

                                                QUERY PLAN
----------------------------------------------------------------------------------------------------------
 Finalize Aggregate (actual time=581.452..594.009 rows=1 loops=1)
   Buffers: shared hit=4032 read=13210
   ->  Gather (actual time=581.354..593.981 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=4032 read=13210
         ->  Partial Aggregate (actual time=573.254..573.256 rows=1 loops=3)
               Buffers: shared hit=4032 read=13210
               ->  Parallel Seq Scan on test_generic_big (actual time=0.022..281.959 rows=333333 loops=3)
                     Buffers: shared hit=4032 read=13210
 Planning Time: 0.113 ms
 Execution Time: 594.124 ms
(12 rows)
*/

explain(analyze, buffers,costs off)
select array_avg(a) as a
from test_generic_big_array \watch c=3
/*
                                     QUERY PLAN
------------------------------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual time=1544.979..1722.415 rows=1 loops=1)
   Buffers: shared hit=256
 Planning Time: 0.106 ms
 Execution Time: 1722.474 ms
(4 rows)
*/