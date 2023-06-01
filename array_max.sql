/*

\i  /home/jian/Desktop/regress_pgsql/array_max.sql
*/
begin;
	alter event trigger search_path_required disable;
	drop FUNCTION if exists array_max(anyarray);
	drop FUNCTION if exists array_max(_numeric);
	CREATE OR REPLACE FUNCTION array_max(anyarray)
	RETURNS anyelement SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_max', 'array_max'
	LANGUAGE c IMMUTABLE STRICT;
	alter event trigger search_path_required enable;
commit;

drop table if exists test_a;
create table test_a as
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

drop table if exists test_arraymax_a;
create table test_arraymax_a as
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
from    test_a;

--validate that results are the same.
(
    SELECT
        max(a) AS a,
        max(b) AS b,
        max(c) AS c,
        max(d) AS d,
        max(e) AS e,
        max(f) AS f,
        max(g) AS g,
        max(h) AS h,
        max(i) AS i,
        max(j) AS j,
        max(k) AS k,
        max(l) AS l,
        max(m) AS m
    FROM
        test_a)
EXCEPT
SELECT
    array_max (a) AS a,
    array_max (b) AS b,
    array_max (c) AS c,
    array_max (d) AS d,
    array_max (e) AS e,
    array_max (f) AS f,
    array_max (g) AS g,
    array_max (h) AS h,
    array_max (i) AS i,
    array_max (j) AS j,
    array_max (k) AS k,
    array_max (l) AS l,
    array_max (m) AS m
FROM
    test_arraymax_a;

--test_performance.
drop table if exists test_b;
create table test_b as
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


drop table if exists test_arraymax_b;
create table test_arraymax_b as
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
from    test_b;

vacuum analyze test_arraymax_b;
vacuum analyze test_b;

--first thing first. validate results are the same. 
(
    SELECT
        max(a) AS a,
        max(b) AS b,
        max(c) AS c,
        max(d) AS d,
        max(e) AS e,
        max(f) AS f,
        max(g) AS g,
        max(h) AS h,
        max(i) AS i,
        max(j) AS j,
        max(k) AS k,
        max(l) AS l,
        max(m) AS m
    FROM
        test_b
)
EXCEPT(
    SELECT
        array_max (a) AS a,
        array_max (b) AS b,
        array_max (c) AS c,
        array_max (d) AS d,
        array_max (e) AS e,
        array_max (f) AS f,
        array_max (g) AS g,
        array_max (h) AS h,
        array_max (i) AS i,
        array_max (j) AS j,
        array_max (k) AS k,
        array_max (l) AS l,
        array_max (m) AS m
    FROM
        test_arraymax_b
);
/*
 a | b | c | d | e | f | g | h | i | j | k | l | m
---+---+---+---+---+---+---+---+---+---+---+---+---
(0 rows)
*/

--test serval time. final result
explain(analyze, buffers,costs off)
SELECT
    max(a) AS a,
    max(b) AS b,
    max(c) AS c,
    max(d) AS d,
    max(e) AS e,
    max(f) AS f,
    max(g) AS g,
    max(h) AS h,
    max(i) AS i,
    max(j) AS j,
    max(k) AS k,
    max(l) AS l,
    max(m) AS m
FROM
    test_b  \watch c=3
/*
                                           QUERY PLAN
------------------------------------------------------------------------------------------------
 Finalize Aggregate (actual time=2337.117..2349.474 rows=1 loops=1)
   Buffers: shared hit=2912 read=14330
   ->  Gather (actual time=2336.751..2349.414 rows=3 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=2912 read=14330
         ->  Partial Aggregate (actual time=2328.736..2328.737 rows=1 loops=3)
               Buffers: shared hit=2912 read=14330
               ->  Parallel Seq Scan on test_b (actual time=0.037..298.146 rows=333333 loops=3)
                     Buffers: shared hit=2912 read=14330
 Planning Time: 0.562 ms
 Execution Time: 2349.758 ms
(12 rows)
*/

explain(analyze, buffers,costs off)
SELECT
    array_max (a) AS a,
    array_max (b) AS b,
    array_max (c) AS c,
    array_max (d) AS d,
    array_max (e) AS e,
    array_max (f) AS f,
    array_max (g) AS g,
    array_max (h) AS h,
    array_max (i) AS i,
    array_max (j) AS j,
    array_max (k) AS k,
    array_max (l) AS l,
    array_max (m) AS m
FROM
    test_arraymax_b \watch c=3
/*
                                 QUERY PLAN
-----------------------------------------------------------------------------
 Seq Scan on test_arraymax_b (actual time=2258.915..2276.187 rows=1 loops=1)
   Buffers: shared hit=5379
 Planning Time: 0.121 ms
 Execution Time: 2276.267 ms
(4 rows)
*/

explain(analyze, buffers,costs off)
select max(s) 
from test_arraymax_b, unnest(a) s   \watch c=3
/*
                                         QUERY PLAN
--------------------------------------------------------------------------------------------
 Aggregate (actual time=2604.046..2604.049 rows=1 loops=1)
   Buffers: shared hit=257, temp read=1465 written=1465
   ->  Nested Loop (actual time=890.135..2216.625 rows=1000000 loops=1)
         Buffers: shared hit=257, temp read=1465 written=1465
         ->  Seq Scan on test_arraymax_b (actual time=0.013..0.018 rows=1 loops=1)
               Buffers: shared hit=1
         ->  Function Scan on unnest s (actual time=890.116..1662.031 rows=1000000 loops=1)
               Buffers: shared hit=256, temp read=1465 written=1465
 Planning Time: 0.130 ms
 Execution Time: 2616.595 ms
(10 rows)
*/

explain(analyze, buffers,costs off)
select array_max (a) AS a
from test_arraymax_b         \watch c=3
/*
                                QUERY PLAN
---------------------------------------------------------------------------
 Seq Scan on test_arraymax_b (actual time=120.642..121.043 rows=1 loops=1)
   Buffers: shared hit=257
 Planning Time: 0.134 ms
 Execution Time: 121.105 ms
(4 rows)
*/

explain(analyze, buffers,costs off)
select * from
(   
    select max(a.a)
    from test_arraymax_b,unnest(a) a
),
(
    select max(b.b)
    from test_arraymax_b,unnest(b) b
) \watch c=3
/*
                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Nested Loop (actual time=5221.247..5221.252 rows=1 loops=1)
   Buffers: shared hit=767, temp read=3174 written=3174
   ->  Aggregate (actual time=2617.282..2617.284 rows=1 loops=1)
         Buffers: shared hit=257, temp read=1465 written=1465
         ->  Nested Loop (actual time=884.925..2224.848 rows=1000000 loops=1)
               Buffers: shared hit=257, temp read=1465 written=1465
               ->  Seq Scan on test_arraymax_b (actual time=0.012..0.018 rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest a (actual time=884.908..1682.065 rows=1000000 loops=1)
                     Buffers: shared hit=256, temp read=1465 written=1465
   ->  Aggregate (actual time=2603.959..2603.960 rows=1 loops=1)
         Buffers: shared hit=510, temp read=1709 written=1709
         ->  Nested Loop (actual time=891.669..2213.160 rows=1000000 loops=1)
               Buffers: shared hit=510, temp read=1709 written=1709
               ->  Seq Scan on test_arraymax_b test_arraymax_b_1 (actual time=0.014..0.019 rows=1 loops=1)
                     Buffers: shared hit=1
               ->  Function Scan on unnest b (actual time=891.648..1670.402 rows=1000000 loops=1)
                     Buffers: shared hit=509, temp read=1709 written=1709
 Planning Time: 0.307 ms
 Execution Time: 5235.490 ms
(20 rows)
*/

explain(analyze, buffers,costs off)
select array_max (a) AS a,array_max (b) AS b
from test_arraymax_b         \watch c=3
/*
                                QUERY PLAN
---------------------------------------------------------------------------
 Seq Scan on test_arraymax_b (actual time=242.276..243.178 rows=1 loops=1)
   Buffers: shared hit=766
 Planning Time: 0.117 ms
 Execution Time: 243.242 ms
(4 rows)
*/