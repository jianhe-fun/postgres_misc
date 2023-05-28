/*
    make sure foreign key at least one key is there. FOR KEY SHARE LOCK 
    https://www.cybertec-postgresql.com/en/lock-table-can-harm-your-database/
    https://www.cybertec-postgresql.com/en/vacuum-does-not-shrink-my-postgresql-table/
*/

BEGIN;
    CREATE SCHEMA atleast1;
    SET search_path to atleast1;

CREATE TABLE atleast1.pk1(pk1id integer PRIMARY KEY, misc_pk1 text NOT NULL);
CREATE TABLE atleast1.pk2(pk2id integer PRIMARY KEY, misc_pk2 text NOT NULL);

INSERT INTO atleast1.pk1(pk1id,misc_pk1) VALUES (1, 'miscpk1a '),(2, 'miscpk1 b');
INSERT INTO atleast1.pk2(pk2id,misc_pk2) VALUES  (51, 'Alice'),(52, 'Bob'),(53, 'Chris'),(54, 'Daniel'),(55, 'enn'),

CREATE TABLE atleast1.fk(
    pk1id integer REFERENCES pk1(pk1id)
    ,pk2id  integer REFERENCES pk2(pk2id)
    ,PRIMARY KEY (pk1id,pk2id)
);

INSERT INTO atleast1.fk (pk1id,pk2id) VALUES(1, 51), (2, 52), (2, 53),(2,54),(1,55);
    
CREATE OR REPLACE FUNCTION atleast1.fkatleast1 ()
    RETURNS TRIGGER
    SET search_path TO atleast1
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF EXISTS ( 
        WITH remaining AS(
            /* for fk record, if multi fk1 key value, at least one pk1id is there. 
             */
            SELECT          fk.pk1id                
            FROM            atleast1.fk                
            JOIN deleted    ON fk.pk1id = deleted.pk1id
            ORDER BY    fk.pk1id,fk.pk2id                            
            /* lock those remaining entries */
            FOR key share OF fk
        )
        SELECT  pk1id FROM deleted                                
        EXCEPT
        SELECT  pk1id FROM remaining
        ) 
        THEN        
            RAISE EXCEPTION 'cannot leave a prison without guards';
    END IF;
    RETURN NULL;
END
$$;

CREATE OR REPLACE TRIGGER fkatleast1
    AFTER DELETE ON atleast1.fk referencing old TABLE AS deleted FOR EACH statement
    EXECUTE PROCEDURE atleast1.fkatleast1 ();

COMMIT;

----------------------------------------------------------------------------------------------
--session 1
begin;
    SET search_path to atleast1;
    delete from fk where pk2id = 52 RETURNING *;

    --session 2 --- will  hang util session1 release;
    begin;
        SET search_path to atleast1;
        delete from fk where pk2id = 53 RETURNING *;

----------------------------------------------------------------------------------------------
--session 1
begin;
    --pk1 id = 2
    SET search_path to atleast1;
    delete from fk where pk2id = 52 RETURNING *;

    --session 2 --- will be fine since. pk1id is 1
    begin;
        SET search_path to atleast1;
        delete from fk where pk2id = 55 RETURNING *;
    rollback; 
--session1 rollback.
rollback;

---clean up.
DROP SCHEMA atleast1 CASCADE;




