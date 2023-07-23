

CREATE UNLOGGED TABLE test_btree AS
    SELECT    g::int    FROM    generate_series(1 , 1e6) g;
ALTER TABLE test_btree SET (autovacuum_enabled = FALSE);
CREATE INDEX test_btree_idx ON test_btree USING btree (g) WITH (fillfactor = 70);

SELECT  relpages    
FROM    pg_class 
WHERE relname = 'test_btree_idx'; -- 3537

/*
    walking through btree leaf pages, should be true for following statement: 
    (sum of all btree live items except all the high keys) == number of items(tuples) on main heap table
*/
WITH RECURSIVE cte (leaf,NEXT,entries) AS 
(
    SELECT
        node.blkno AS leaf,
        node.btpo_next AS next,
        /*
         every leaf page have one high_key except ending left page.
         ending leaf page next page point to 0.
         so for every leaf page (except ending), 
         there are only live_items minus one live items pointer to heap page.(no consider of duplication).
         */
        node.live_items - (node.btpo_next <> 0)::int AS entries
    FROM
        pg_class pc,
        LATERAL generate_series(1, pc.relpages - 1) AS p,
        LATERAL bt_page_stats ('test_btree_idx', p) AS node
    WHERE
        pc.relname = 'test_btree_idx'
        AND pc.relkind = 'i'
        AND node.type = 'l'
        AND node.btpo_prev = 0
    UNION ALL
    SELECT
        node.blkno AS leaf,
        node.btpo_next AS next,
        node.live_items - (node.btpo_next <> 0)::int AS entries
        /* same as privously comment*/
    FROM
        cte,
        LATERAL bt_page_stats ('test_btree_idx', cte.next) AS node
    WHERE
        cte.next <> 0
)
SELECT *, sum(entries) OVER ()
FROM    cte
ORDER BY    leaf,   NEXT
LIMIT 10;   /*data sample*/

DROP TABLE test_btree;