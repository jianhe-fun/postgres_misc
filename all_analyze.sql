
/*
logic, condition when autovacuum will invoke auto_analyze.
    pg_stat_all_tables.n_mod_since_analyze >
        autovacuum_analyze_threshold 
        + autovacuum_analyze_scale_factor × pg_class.reltuples
*/

--helper function.
CREATE FUNCTION pgclass_params (param text, c pg_class)
    RETURNS float
    SET search_path FROM    current
    AS $$
    SELECT
        coalesce((
            SELECT  option_value                
            FROM    pg_catalog.pg_options_to_table(c.reloptions)
        WHERE
            option_name = CASE WHEN c.relkind = 't' THEN    'toast.'                
            ELSE    ''                
            END || param),  current_setting(param))::float;
    $$
LANGUAGE sql;

CREATE OR REPLACE VIEW need_analyze AS
WITH cte AS (
    --https://www.postgresql.org/docs/current/runtime-config-autovacuum.html
    SELECT
        pc.oid,
        greatest (pc.reltuples, 0) AS reltuples, -- -1 indicate unknown.
        pgclass_params ('autovacuum_analyze_threshold', pc) threhold,
        pgclass_params ('autovacuum_analyze_scale_factor', pc) scale_factor
    FROM
        pg_class pc
    WHERE
        pc.relkind IN ('r', 'm'))
SELECT
    st.schemaname || '.' || st.relname AS tablename,
    c.reltuples                 --number of live rows in the table. estimate.
    --Estimated number of rows modified since this table was last analyzed
    ,st.n_mod_since_analyze AS est_mod_tup,
    /*the threhold to trigger auto_vacuum do analyze work.*/
    c.threhold + c.scale_factor * c.reltuples AS max_mod_tup,
    st.last_autoanalyze,    --last time autovacuum do autoanalyze
    st.last_analyze         --last time do manual analyze.
FROM
    pg_stat_all_tables st
    JOIN cte c ON c.oid = st.relid

-------------------------------------------------------------
CREATE OR REPLACE PROCEDURE analyze_it (_schema text DEFAULT NULL)
LANGUAGE plpgsql
AS $proc$
DECLARE
    target_rel text;
    target_schema text;
BEGIN
    -- raise notice '_schema %',_schema;
    IF _schema IS NOT NULL THEN         --analyze per schema.        
        FOR target_rel IN
            SELECT  tablename
            FROM    need_analyze
            --since  est_mod_tup is pretty accurate. this should be fine.
            WHERE   est_mod_tup > (max_mod_tup * 0.9)            
            AND     split_part(tablename, '.', 1) = $1 --specify the schema.
        LOOP
            -- raise notice 'target_rel is %', target_rel;
            EXECUTE $sql$ANALYZE (skip_locked, BUFFER_USAGE_LIMIT '1024 kB') $sql$ || target_rel;
            COMMIT;     --commit chain. batch commit. so this procedure cannot be nested.
        END LOOP;
    ELSE
        --analyze all schema.
        FOR target_rel IN
            SELECT      tablename            
            FROM        need_analyze            
            --since  est_mod_tup is pretty accurate. this should be fine.
            WHERE       est_mod_tup > (max_mod_tup * 0.9)            
        LOOP
            -- RAISE NOTICE 'target_rel is %', target_rel;
            EXECUTE $sql$ANALYZE (skip_locked, BUFFER_USAGE_LIMIT '1024 kB') $sql$ || target_rel;
            COMMIT;     --commit chain. batch commit. so this procedure cannot be nested.            
        END LOOP;
    END IF;
END
$proc$;

----------- 1 way test n_mod_since_analyze is pretty accurate.
create table tenk3 (like tenk1 including all ); 
alter table tenk3 set (autovacuum_enabled=false,autovacuum_vacuum_scale_factor=0.9,fillfactor=80);
truncate tenk3;
insert into tenk3 select * from tenk1;
select * from need_analyze where tablename ~* 'tenk3';
update tenk3 set unique1 = unique1;
update tenk3 set unique1 = unique1 where random() > 0.5; 
select * from need_analyze where tablename = 'public.tenk3' \gx
CALL analyze_it ('public');
drop table tenk3;
----------- 2. way test n_mod_since_analyze is pretty accurate.
create table tenk3 (like tenk1 including all ); 
alter table tenk3 set (autovacuum_enabled=false,autovacuum_vacuum_scale_factor=0.9,fillfactor=80);
COPY tenk3 from '/home/jian/Desktop/test.csv' WITH  (format csv,delimiter '|', header);
select * from need_analyze where tablename ~* 'tenk3';
select * from need_analyze where tablename = 'public.tenk3' \gx
CALL analyze_it ('public');
drop table tenk3;