
/*
https://github.com/ioguix/pgsql-bloat-estimation/blob/master/btree/btree_bloat-superuser.sql
    index bloat estimation. Require superuser priviledge to read table pg_statistic.
    base on url repo, more explanation, and minor optimization. 

demo: 
select * from index_bloat order by bloat_pct desc nulls last limit 1;
            current_database | test16
            schema           | public
            tblname          | pgbench_tellers
            idxname          | pgbench_tellers_pkey
            real_size        | 1654784
            extra_size       | 1638400
            extra_pct        | 99.00990099009901
            fillfactor       | 90
            bloat_size       | 1638400
            bloat_pct        | 99.00990099009901
            is_na            | f
            relpages         | 202
            est_pages_ff     | 2

reindex (VERBOSE)  index pgbench_tellers_pkey;

select * from index_bloat where idxname = 'pgbench_tellers_pkey' \gx
        current_database | test16
        schema           | public
        tblname          | pgbench_tellers
        idxname          | pgbench_tellers_pkey
        real_size        | 16384
        extra_size       | 0
        extra_pct        | 0
        fillfactor       | 90
        bloat_size       | 0
        bloat_pct        | 0
        is_na            | f
        relpages         | 2
        est_pages_ff     | 2

works fine. In most case.
*/
create or replace view index_bloat AS
SELECT
    current_database()
    ,nspname    as schema
    ,tblname
    ,idxname
    ,bs::bigint * relpages                  as real_size
    ,bs * (relpages - est_pages)::bigint    as extra_size
    ,100 * (relpages - est_pages)::float/relpages   as extra_pct
    ,fillfactor
    ,case   when relpages > est_pages_ff 
            then bs * (relpages - est_pages_ff) else 0 
    end as bloat_size
    ,100 * (relpages-est_pages_ff)::float/relpages   as bloat_pct
    ,is_na
    ,relpages
    ,est_pages_ff
FROM
(
    SELECT
        coalesce(1 + ceil(reltuples/floor((bs-pageopqdata - pagehdr)/(4 + nulldatahdrwidth)::float)),0)
            AS est_pages
        ,coalesce(1 + ceil(reltuples/
                        floor((bs-pageopqdata - pagehdr) * fillfactor/
                                    (100 * (4 + nulldatahdrwidth)::float))),0)
            AS est_pages_ff
        ,bs
        ,nspname
        ,tblname
        ,idxname
        ,reltuples
        ,relpages
        ,fillfactor
        ,is_na       
    FROM
    (
        select
            maxalign
            ,bs
            ,nspname
            ,tblname
            ,idxname
            ,reltuples
            ,relpages
            ,idxoid
            ,fillfactor
            ,(index_tuplr_hdr_bm + maxalign 
                -   case when index_tuplr_hdr_bm % maxalign = 0 then maxalign
                    else  index_tuplr_hdr_bm % maxalign 
                    end
                +   nulldatawidth + maxalign
                -   case  when nulldatawidth =  0  then 0
                        when nulldatawidth::int % maxalign = 0 then maxalign
                        else nulldatawidth::int % maxalign
                    end)::numeric   as nulldatahdrwidth -- header+ actual data.
            ,pagehdr
            ,pageopqdata
            ,is_na
        FROM
            (
                select
                    n.nspname
                    ,ct.relname as tblname
                    ,sub.idxname
                    ,sub.reltuples
                    ,sub.relpages
                    ,sub.idxoid
                    ,sub.fillfactor
                    ,current_setting('block_size')::int  as bs      --block size.default is 8192.
                    ,case when version() ~* 'mingw32' OR version()  ~ '64-bit|x86_64|ppc64|ia64|amd64'  
                            then  8 else 4 
                    end as          maxalign

                    ,24     as      pagehdr                              
                    /* per page header, fixed size: 20 for 7.X, 24 for others */
                    ,16::int     as pageopqdata                     
                    /* per page btree opaque data */
                    ,case   when    max(coalesce(s.stanullfrac,0)) = 0 then 8
                    else           8 + ((32 + 8 -1)/8) 
                    -- IndexTupleData size + IndexAttributeBitMapData size ( max num filed per index + 8 - 1 /8)
                    end    as index_tuplr_hdr_bm
                    ,sum( (1 - coalesce(s.stanullfrac,0)) * coalesce(s.stawidth,1024)) AS nulldatawidth     
                    --tuple actual data exclude null.
                    ,max(case when att.atttypid = 'pg_catalog.name'::regtype then 1 else 0 end) > 0 AS is_na
                FROM
                (
                    select  idxoid
                            ,idxname
                            ,reltuples
                            ,relpages
                            ,tbloid
                            ,fillfactor
                            ,case when ind_attnum = 0 then idxoid else tbloid end as attrel     
                            ,CASE WHEN ind_attnum = 0 THEN nr ELSE ind_attnum END AS ind_attnum
                            /*  the above two case statement take care of special case
                                create table s12; create index s12idx on s12((s12));
                            */
                    from
                    (
                        select 
                                idxoid
                                ,idxname
                                ,reltuples
                                ,relpages
                                ,tbloid
                                ,fillfactor
                                ,indkeys
                                ,ind_attnum --unnest, expand to each index's column's related pg_attribute attnum
                                ,nr         --unnest    ORDINALITY number.
                        from
                        (
                            select
                                    pc.relname     idxname --index name
                                    ,pc.reltuples           --index live tuples
                                    ,pc.relpages            -- index pages
                                    ,pi.indrelid    tbloid  -- table oid
                                    ,pi.indexrelid  idxoid
                                    ,pi.indnatts            --no of columns this index involed with
                                    ,string_to_array(pi.indkey::text, ' ')::int2[] indkeys 
                                                            --array of {index column attnum}
                                    ,coalesce(substring(array_to_string(pc.reloptions, ' ')
                                            FROM 'fillfactor=([0-9]+)')::smallint, 90) AS fillfactor
                                    ,pc.relam               --access method           
                            from    pg_index        pi
                            join    pg_class        pc
                            on      pc.oid  = pi.indexrelid
                            where   pc.relnamespace = 'public'::regnamespace
                            and     pc.relam        = (select oid from pg_am am where amname   = 'btree')
                            and     pc.relkind  in ('i')   
                                --to avoid corner case, paritioned table. index is 0.                                
                            )sub, unnest(indkeys) WITH ORDINALITY AS a(ind_attnum, nr)
                    )sub
                )sub
                join    pg_attribute    att     
                        on att.attnum   = sub.ind_attnum and att.attrelid   =  sub.attrel
                join    pg_statistic    s       
                        on s.starelid   = sub.attrel       and s.staattnum = sub.ind_attnum
                join    pg_class        ct      
                        on ct.oid       = sub.tbloid
                join    pg_namespace    n       
                        on n.oid        = ct.relnamespace   
                GROUP   BY 1,2,3,4,5,6,7,8,9,10
                )as row_data_stats
            )row_hdr_pdg_stats
        )relation_stats
ORDER BY nspname, tblname, idxname;