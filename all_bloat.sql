/*
    * only deal with table, materialized view bloat, not index.
    * http://blog.ioguix.net/postgresql/2014/03/28/Playing-with-indexes-and-better-bloat-estimate.html
    * https://wiki.postgresql.org/wiki/Index_Maintenance
    * https://www.pgcon.org/2009/schedule/attachments/96_visualizing-postgres-2009-05-21.pdf
    * https://www.cybertec-postgresql.com/en/estimating-table-bloat/

--populate pgbench.
	/home/jian/postgres/pg16_test/bin/pgbench -i -s10 test16
--insert data, make it bloat, to make it bloat, you need another transaction open. Like select * from pgbench_account limit 1;
	/home/jian/postgres/pg16_test/bin/pgbench --no-vacuum --client=2 --jobs=2 --transactions=250000 --protocol=prepared test16

most of the time, works fine, unless comparitively more TOAST pages.

SELECT	approx_free_space
		,approx_free_percent
		,'|'	as vs
		,bloat_size
		,bloat_pct  
from bloat
	,pgstattuple_approx('public.pgbench_accounts'::regclass) sp
where tblname = 'pgbench_accounts' and schemaname = 'public';

 approx_free_space | approx_free_percent | vs | bloat_size |     bloat_pct
-------------------+---------------------+----+------------+-------------------
          66382272 |   32.95231868366476 | |  |   69058560 | 34.28083445162864
*/

create or replace view bloat	as
SELECT	current_database()					--database
		,schemaname							--schema
		,tblname							--tablename
		,bs * tblpages AS real_size			-- real_size (only main relation)
		,(tblpages-est_tblpages)*bs AS extra_size	--estimate extra free size can be reused 
		,CASE WHEN tblpages > 0 AND tblpages - est_tblpages > 0 THEN 100 * (tblpages - est_tblpages)/tblpages::float
    		ELSE 0
		END AS extra_pct					--estimate extra free size percent can be reused
		,fillfactor							--fillfactor
		,CASE WHEN tblpages - est_tblpages_ff > 0	THEN (tblpages-est_tblpages_ff)	* bs
    	ELSE 0
  		END AS bloat_size,					--estimate extra free size can be reused with fillfactor fillfactor. 
  		CASE	WHEN tblpages > 0 AND tblpages - est_tblpages_ff > 0
    			THEN 100 * (tblpages - est_tblpages_ff)/tblpages::float 
											--estimate extra free size can be reused, consider fillfactor. 
    	ELSE 0
  		END AS bloat_pct
		,is_na
  		-- , tpl_hdr_size, tpl_data_size, (pst).free_percent + (pst).dead_tuple_percent AS real_frag -- (DEBUG INFO)
FROM (
  	SELECT 
			ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil(toasttuples / 4) AS est_tblpages
    		,ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil(toasttuples / 4) AS est_tblpages_ff
    		,tblpages
			,fillfactor
			,bs
			,tblid
			,schemaname
			,tblname
			,heappages
			,toastpages
			,is_na
    		-- , tpl_hdr_size, tpl_data_size, pgstattuple(tblid) AS pst -- (DEBUG INFO)
  	FROM 
  	(
    SELECT
      	(4 + tpl_hdr_size + tpl_data_size + (2*ma)
        - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
        - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
     	) AS tpl_size                        	--- average tuple include header, actual data, size.
		,bs - page_hdr AS size_per_block      	--exclude page header.
		,(heappages + toastpages) AS tblpages 	--regular page + toast page.
		,heappages   	 						-- head pages count         
		,toastpages    							-- toast pages count  
		,reltuples    							--no toast tuples count
		,toasttuples  							--toast tuples
		,bs           							--page size
		,page_hdr     							--page header
		,tblid        							--table oid
		,schemaname								--schema
		,tblname      							--table name
		,fillfactor   							--fillfactor
		,is_na        							--should be false.
      	, tpl_hdr_size, tpl_data_size
    FROM 
      	(
          	SELECT
				tbl.oid AS tblid
				,ns.nspname AS  schemaname
				,tbl.relname AS tblname
				,tbl.reltuples
				,tbl.relpages AS heappages
				,coalesce(toast.relpages, 0) AS toastpages
				,coalesce(toast.reltuples, 0) AS toasttuples
				,coalesce(substring(array_to_string(tbl.reloptions, ' ')
						FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor   -- fillfator
				,current_setting('block_size')::numeric AS bs                       -- block size
				,CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma
											--MAXALIGN binary pg_controldata variable "Maximum data alignment" value
				,24 AS page_hdr         											--page header.
				,23 + CASE WHEN MAX(coalesce(s.null_frac,0)) > 0 THEN ( 7 + count(s.attname) ) / 8 ELSE 0::int END
					+ CASE WHEN bool_or(att.attname = 'oid' and att.attnum < 0) THEN 4 ELSE 0 END 
					AS tpl_hdr_size     											-- with null fill in row header size.
				,sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 0) ) AS tpl_data_size
				,bool_or(att.atttypid = 'pg_catalog.name'::regtype)					--edge case create table s().
					OR  count(att.attname) filter (where att.attnum > 0) <>  count(s.attname) AS is_na        
          FROM pg_attribute AS att
          JOIN pg_class AS tbl ON att.attrelid = tbl.oid
          JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
          LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname
                                  AND s.tablename 	= tbl.relname 
                                  AND s.inherited	= false 
                                  AND s.attname		= att.attname
          LEFT JOIN pg_class AS toast 
                                  ON tbl.reltoastrelid = toast.oid
          WHERE NOT att.attisdropped		--ignored droppped column.
		  AND	att.attnum	> 0				--ignore the system column, otherwise is_na will be evaulated to true	
          AND tbl.relkind in ('r','m')		--only for materialzied view, regular table.
          GROUP BY 1,2,3,4,5,6,7,8,9,10	
          ORDER BY 2,3
      	) AS s
  	) AS s2
) AS s3
-- WHERE NOT is_na
--   AND tblpages*((pst).free_percent + (pst).dead_tuple_percent)::float4/100 >= 1
ORDER BY schemaname, tblname;
