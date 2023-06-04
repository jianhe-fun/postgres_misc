/*
    array_min function setup. and some benchmark.
    array_median.sql
*/
begin;
    drop function if exists array_median(int2[]);
    drop function if exists array_median(int4[]);
    drop function if exists array_median(int8[]);
    drop function if exists array_median(numeric[]);
    drop function if exists array_median(date[]);
    drop function if exists array_median(interval[]);
    drop function if exists array_median(timestamp[]);
    drop function if exists array_median(timestamptz[]);

	CREATE OR REPLACE FUNCTION array_median(int2[])
	RETURNS int2 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_median', 'array_median'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_median(int4[])
	RETURNS int4 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_median', 'array_median'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_median(int8[])
	RETURNS int8 SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_median', 'array_median'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_median(numeric[])
	RETURNS numeric SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_median', 'array_median'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_median(date[])
	RETURNS date SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_median', 'array_median'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_median(timestamp[])
	RETURNS timestamp SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_median', 'array_median'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_median(timestamptz[])
	RETURNS timestamptz SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_median', 'array_median'
	LANGUAGE c IMMUTABLE STRICT;

	CREATE OR REPLACE FUNCTION array_median(interval[])
	RETURNS interval SET search_path from current
	AS '/home/jian/Desktop/regress_pgsql/array_median', 'array_median'
	LANGUAGE c IMMUTABLE STRICT;
commit;

select array_median('{1,11,13,13}'::numeric[]);

select array_median('{1,11,13,13}'::numeric[])
		,array_median('{1,11,13,13}'::int2[])
		,array_median('{1,11,13,13}'::int4[])
		,array_median('{1,11,13,13}'::int8[]);

select	array_median('{1,11,12,23,33}'::int2[])
		,array_median('{1,11,12,23,33}'::int4[])
		,array_median('{1,11,12,23,33}'::int8[])
		,array_median('{1,11,12,23,23}'::numeric[]);


select  array_median('{1,2,3,4,5,null,null}'::int8[])   as int8min
        ,array_median('{1,2,3,4,5,null,null}'::int4[])  as int4min
        ,array_median('{1,2,3,4,5,null,null}'::int2[])  as in2min
        ,array_median('{1,2,3,4,5,null,null}'::numeric[]) as numericmin
        ,array_median('{1s,2s,3s,4s,5s,null,null}'::interval[]) as intevalmin
        ,array_median('{0s,1s,2s,3s,4s,5s,null,null}'::interval[]) as intevalmin;

select  array_median('{null,NULL,NULL}'::int2[]) 
        ,array_median('{null,NULL,NULL}'::int4[])
        ,array_median('{null,NULL,NULL}'::int8[])
        ,array_median('{null,NULL,NULL}'::numeric[]);

-- select array_median(null::int8[]),array_median(null::numeric[]),array_median(null::int4[]),array_median(null::int2[]);

select array_median('{}'::int8[]);     
select array_median('{}'::numeric[]);     
select array_median('{}'::int4[]);     
select array_median('{}'::int2[]);     
------------------------------------------------------	
select percentile_disc(0.5) WITHIN GROUP (ORDER BY a)
from	test_generic
except all
select array_median(a) from test_generic_array;

(select 
	percentile_disc(0.5) WITHIN GROUP (ORDER BY a)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY b)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY c)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY f)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY g)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY i)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY k)
from	test_generic
)
except all
(
select 	array_median(a) 
		,array_median(b) 
		,array_median(c) 
		,array_median(f) 
		,array_median(g) 
		,array_median(i) 
		,array_median(k) 
from test_generic_array
)

--validate
(select 
	percentile_disc(0.5) WITHIN GROUP (ORDER BY a)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY b)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY c)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY f)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY g)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY i)
	,percentile_disc(0.5) WITHIN GROUP (ORDER BY k)
from	test_generic_big
)
except all
(
	select 	array_median(a) 
			,array_median(b) 
			,array_median(c) 
			,array_median(f) 
			,array_median(g) 
			,array_median(i) 
			,array_median(k) 
	from test_generic_big_array
);

explain(costs off, analyze, timing off, buffers)
select percentile_disc(0.5) WITHIN GROUP (ORDER BY a)
from	test_generic_big;

explain(costs off, analyze, timing off, buffers)
select 	array_median(a) 
from (select array_agg(a) from test_generic_big s) s(a); 


explain(costs off, analyze, timing off, buffers)
select percentile_disc(0.5) WITHIN GROUP (ORDER BY k)
from	test_generic_big;
/*
                            QUERY PLAN
-------------------------------------------------------------------
 Aggregate (actual rows=1 loops=1)
   Buffers: shared hit=192 read=17050, temp read=3826 written=4911
   ->  Seq Scan on test_generic_big (actual rows=1000000 loops=1)
         Buffers: shared hit=192 read=17050
 Planning Time: 0.210 ms
 Execution Time: 6428.542 ms
(6 rows)
*/

explain(costs off, analyze, timing off, buffers)
select 	array_median(k) 
from (select array_agg(a) from test_generic_big s) s(k); 
/*
                                 QUERY PLAN
----------------------------------------------------------------------------
 Subquery Scan on s (actual rows=1 loops=1)
   Buffers: shared hit=224 read=17018
   ->  Aggregate (actual rows=1 loops=1)
         Buffers: shared hit=224 read=17018
         ->  Seq Scan on test_generic_big s_1 (actual rows=1000000 loops=1)
               Buffers: shared hit=224 read=17018
 Planning Time: 0.345 ms
 Execution Time: 1532.397 ms
(8 rows)
*/
