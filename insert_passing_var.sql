/*
passing var while insert.
    use trigger. instead of insert on the base table, create a updateable view.
    do different operation when is the var is different.
*/
BEGIN;

DROP TABLE IF EXISTS insert_view_extra CASCADE;
DROP VIEW IF EXISTS insert_view_extra_v CASCADE;
DROP FUNCTION IF EXISTS ins_view ();


CREATE TABLE insert_view_extra (
    meta_id int GENERATED ALWAYS AS IDENTITY,
    name    text
);

CREATE VIEW insert_view_extra_v AS
SELECT
    *,
    NULL::int AS site_id
FROM
    insert_view_extra;

-- trigger func
CREATE OR REPLACE FUNCTION ins_view ()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    set search_path from current
    AS $func$
BEGIN
    CASE NEW.site_id
    WHEN 1 THEN
        INSERT INTO insert_view_extra (name) VALUES (NEW.name); --will insert to based table.
        RETURN new;                                             --will aslo insert to view
    WHEN 2 THEN
        INSERT INTO insert_view_extra (name) VALUES (NEW.name); --will insert to based table.
        RETURN NULL;                    --will not insert to view. so returning nothing will show.
    WHEN 0 THEN
        RETURN NULL;    
    ELSE
        RAISE EXCEPTION 'unexpected site_id:%', NEW.site_id;
    END CASE;
END
$func$;

comment on function ins_view is 
$$
https://dba.stackexchange.com/questions/303502/pass-a-variable-with-insert-update-delete-statements/303546#303546
$$;

CREATE TRIGGER insert_view_extra_trig
    INSTEAD OF INSERT ON insert_view_extra_v FOR EACH ROW
    EXECUTE FUNCTION ins_view ();
COMMIT;


---------------test time.
-- missing or unexpected site_id raises custom exception
INSERT INTO insert_view_extra_v (name)
    VALUES ('xxx') RETURNING *;

INSERT INTO insert_view_extra_v (name, site_id)
    VALUES ('xxx', 7);

-- propagated normally
INSERT INTO insert_view_extra_v (name, site_id)
    VALUES ('bar', 1)   RETURNING *;

-- propagated normally, but "meta_id" is always ignored (default IDENTITY used)
INSERT INTO insert_view_extra_v (meta_id, name, site_id)
    VALUES (1, 'baz', 1);

-- INSERT is propagated, but not reported and Postgres stops there
INSERT INTO insert_view_extra_v (name, site_id)
    VALUES ('bam', 2)   RETURNING *;

-- INSERT cancelled silently. view and base table, nothing will be show.
INSERT INTO insert_view_extra_v (name, site_id)
    VALUES ('xxx', 0)   RETURNING *;

-- INSERT works. will be in the view and base table.
INSERT INTO insert_view_extra_v (meta_id, name, site_id)
    VALUES (DEFAULT, 'test. returning should showing this', 1) returning *;

--clean up.
DROP TABLE IF EXISTS insert_view_extra CASCADE;
DROP VIEW IF EXISTS insert_view_extra_v CASCADE;
DROP FUNCTION IF EXISTS ins_view ();

