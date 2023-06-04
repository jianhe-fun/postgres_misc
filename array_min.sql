/*
    array_min function setup. and some benchmark.
*/
begin;
	CREATE OR REPLACE FUNCTION array_min(int2[])
	RETURNS int2 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(int4[])
	RETURNS int4 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(int8[])
	RETURNS int8 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(float4[])
	RETURNS float4 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(float8[])
	RETURNS float8 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(date[])
	RETURNS date SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(time[])
	RETURNS time SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(timetz[])
	RETURNS timetz SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(timestamp[])
	RETURNS timestamp SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(timestamptz[])
	RETURNS timestamptz SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(interval[])
	RETURNS interval SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(pg_lsn[])
	RETURNS pg_lsn SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_min(numeric[])
	RETURNS numeric SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_min', 'array_min'
	LANGUAGE c IMMUTABLE STRICT;
commit;

select  array_min('{1,2,3,4,5,null,null}'::int8[])   as int8min
        ,array_min('{1,2,3,4,5,null,null}'::int4[])  as int4min
        ,array_min('{1,2,3,4,5,null,null}'::int2[])  as in2min
        ,array_min('{1,2,3,4,5,null,null}'::numeric[]) as numericmin
        ,array_min('{1s,2s,3s,4s,5s,null,null}'::interval[]) as intevalmin
        ,array_min('{0s,1s,2s,3s,4s,5s,null,null}'::interval[]) as intevalmin;

select  array_min('{null,NULL,NULL}'::int2[]) 
        ,array_min('{null,NULL,NULL}'::int4[])
        ,array_min('{null,NULL,NULL}'::int8[])
        ,array_min('{null,NULL,NULL}'::numeric[]);

select array_min(null::int8[]),array_min(null::numeric[]),array_min(null::int4[]),array_min(null::int2[]);

select array_min('{}'::int8[]);     
select array_min('{}'::numeric[]);     
select array_min('{}'::int4[]);     
select array_min('{}'::int2[]);     


--validate that results are the same.
(
    SELECT min(a) AS a,min(b) AS b,min(c) AS c,min(d) AS d,min(e) AS e,min(f) AS f
    FROM test_generic
)
EXCEPT ALL
SELECT
    array_min (a) AS a,
    array_min (b) AS b,
    array_min (c) AS c,
    array_min (d) AS d,
    array_min (e) AS e,
    array_min (f) AS f
FROM    test_generic_array;



--first thing first. validate results are the same. 
(
    SELECT
        min(a) AS a,min(b) AS b, min(c) AS c,               
        min(d) AS d, min(e) AS e,min(f) AS f, min(g) AS g,        
        min(h) AS h,min(i) AS i, min(j) AS j,           
        min(k) AS k, min(l) AS l,min(m) AS m    
    FROM
        test_generic_big
)
EXCEPT ALL(
    SELECT
        array_min (a) AS a,array_min (b) AS b,        
        array_min (c) AS c,array_min (d) AS d,    
        array_min (e) AS e,array_min (f) AS f,
        array_min (g) AS g,array_min (h) AS h,        
        array_min (i) AS i,array_min (j) AS j,        
        array_min (k) AS k,array_min (l) AS l,        
        array_min (m) AS m
    FROM
        test_generic_big_array
);
/*
 a | b | c | d | e | f | g | h | i | j | k | l | m
---+---+---+---+---+---+---+---+---+---+---+---+---
(0 rows)
*/


explain(analyze, buffers,costs off,timing off)
SELECT
    min(a) AS a,
    min(b) AS b,
    min(c) AS c,
    min(d) AS d,
    min(e) AS e,
    min(f) AS f,
    min(g) AS g,
    min(h) AS h,
    min(i) AS i,
    min(j) AS j,
    min(k) AS k,
    min(l) AS l,
    min(m) AS m
FROM
    test_generic_big  \watch c=3
/*

                                      QUERY PLAN
--------------------------------------------------------------------------------------
 Finalize Aggregate (actual rows=1 loops=1)
   Buffers: shared hit=1024 read=16218
   ->  Gather (actual rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=1024 read=16218
         ->  Partial Aggregate (actual rows=1 loops=3)
               Buffers: shared hit=1024 read=16218
               ->  Parallel Seq Scan on test_generic_big (actual rows=333333 loops=3)
                     Buffers: shared hit=1024 read=16218
 Planning Time: 0.572 ms
 Execution Time: 2303.833 ms
(12 rows)
*/

explain(analyze, buffers,costs off,timing off)
SELECT
    array_min (a) AS a,
    array_min (b) AS b,
    array_min (c) AS c,
    array_min (d) AS d,
    array_min (e) AS e,
    array_min (f) AS f,
    array_min (g) AS g,
    array_min (h) AS h,
    array_min (i) AS i,
    array_min (j) AS j,
    array_min (k) AS k,
    array_min (l) AS l,
    array_min (m) AS m
FROM
    test_generic_big_array \watch c=3
/*
                         QUERY PLAN
------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual rows=1 loops=1)
   Buffers: shared hit=5376
 Planning Time: 0.120 ms
 Execution Time: 2310.249 ms
(4 rows)
*/

explain(analyze, buffers,costs off,timing off)
select min(s) 
from test_generic_big_array, unnest(a) s   \watch c=3
/*
                               QUERY PLAN
------------------------------------------------------------------------
 Aggregate (actual rows=1 loops=1)
   Buffers: shared hit=256, temp read=1465 written=1465
   ->  Nested Loop (actual rows=1000000 loops=1)
         Buffers: shared hit=256, temp read=1465 written=1465
         ->  Seq Scan on test_generic_big_array (actual rows=1 loops=1)
               Buffers: shared hit=1
         ->  Function Scan on unnest s (actual rows=1000000 loops=1)
               Buffers: shared hit=255, temp read=1465 written=1465
 Planning Time: 0.138 ms
 Execution Time: 2450.015 ms
(10 rows)
*/


explain(analyze, buffers,costs off,timing off)
select array_min (a) AS a
from test_generic_big_array         \watch c=3
/*
                         QUERY PLAN
------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual rows=1 loops=1)
   Buffers: shared hit=256
 Planning Time: 0.108 ms
 Execution Time: 121.636 ms
(4 rows)
*/

explain(analyze, buffers,costs off,timing off)
select * from
    (select min(a.a) from test_generic_big_array,unnest(a) a),
    (select min(b.b) from test_generic_big_array,unnest(b) b) \watch c=3
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
 Planning Time: 0.306 ms
 Execution Time: 4896.413 ms
(20 rows)
*/

explain(analyze, buffers,costs off,timing off)
select array_min (a) AS a,array_min (b) AS b
from test_generic_big_array         \watch c=3
/*
                         QUERY PLAN
------------------------------------------------------------
 Seq Scan on test_generic_big_array (actual rows=1 loops=1)
   Buffers: shared hit=765
 Planning Time: 0.120 ms
 Execution Time: 246.716 ms
(4 rows)
*/