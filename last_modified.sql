
-----update last modified values every time insert/update.
CREATE TABLE test_modified (
    tid     smallint    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    misc    text        UNIQUE,
    misc1   text,
    last_modified timestamptz   --last change to one specific row.
);

CREATE OR REPLACE FUNCTION last_modified ()
    RETURNS TRIGGER
    SET search_path TO public
    LANGUAGE plpgsql
    AS $func$
BEGIN
    -- https://www.postgresql.org/docs/current/functions-json.html
    NEW := json_populate_record(NEW, json_build_object(TG_ARGV[0], now()));
    -- raise notice 'new %',new;
    RETURN NEW;
END
$func$;

CREATE OR REPLACE TRIGGER  last_modified
BEFORE INSERT OR UPDATE ON  test_modified
FOR EACH ROW EXECUTE FUNCTION last_modified('last_modified');

--make consistent sequence value.
TRUNCATE test_modified;
SELECT  setval(pg_get_serial_sequence('test_modified', 'tid'), 42, FALSE);

INSERT INTO test_modified (misc)  VALUES ('type3')   RETURNING *;
INSERT INTO test_modified(misc)  VALUES ('type4')    RETURNING *;
INSERT INTO test_modified(misc)  VALUES ('type5')    RETURNING *;

TABLE test_modified;

UPDATE  test_modified   SET misc1 = 'balbala'
WHERE   tid = 42    RETURNING    *;

UPDATE test_modified SET last_modified = '2021-01-01 12:20:21+08'
WHERE tid = 44    RETURNING   *;

TABLE test_modified;


--- clean up.
drop table test_modified cascade;
