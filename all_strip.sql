
BEGIN;
DROP TABLE IF EXISTS t12 CASCADE;
DROP VIEW IF EXISTS spaces;
DROP FUNCTION IF EXISTS public.strip CASCADE;
DROP PROCEDURE  IF EXISTS generic_text_trigger_transform(regclass, text[], text);

/*
Once for all, remove all the leading and trailing white spaces.
references:
    https://jkorpela.fi/chars/spaces.html
    https://dbfiddle.uk/IcNrq3O1
    https://stackoverflow.com/questions/22699535/trim-trailing-spaces-with-postgresql/22701212#22701212
    https://stackoverflow.com/questions/63302656/remove-all-unicode-space-separators-in-postgresql/63311776#63311776
    https://en.wikipedia.org/wiki/Whitespace_character
    https://www.postgresql.org/docs/current/functions-string.html
*/

CREATE OR REPLACE FUNCTION public.strip()
    RETURNS TRIGGER
    SET search_path FROM    current
    AS $func$
DECLARE
    _sql text;
    arg text;
    _typ CONSTANT regtype[] := '{text,bpchar,name, varchar}';
    _found bool;
    white_space_class text := '[\s\u00a0\u180e\u2007\u200b-\u200f\u202f\u2060\ufeff]+';
    lead_space text := '^' || white_space_class;
    trail_space text := white_space_class || '$';
    rec record;
    argstr text[];
BEGIN
/*
TG_ARGV[].
An optional comma-separated list of arguments to be provided to the function when the trigger is executed. 
The arguments are literal string constants. Simple names and numeric constants can be written here, too, 
but they will all be converted to strings. 
Please check the description of the implementation language of the trigger function
to find out how these arguments can be accessed within the function; 
it might be different from normal function arguments.
example: https://github.com/postgres/postgres/blob/58f5edf849900bc248b7c909ca17da7287306c41/src/test/regress/expected/triggers.out#L846
*/
    FOR i IN 0..TG_nargs - 1 LOOP
        argstr := argstr || TG_argv[i];
    END LOOP;

    SELECT
        INTO _sql,
        _found 'select ' || string_agg(
        CASE WHEN a.atttypid = ANY (_typ) AND attname = ANY (argstr) THEN
            format('regexp_replace(regexp_replace(%1$s,%L,''''),%L,'''' ) as %1$s '
                    , a.col, lead_space, trail_space, a.col)
        ELSE
            col
        END, ', ') || ' FROM (select ($1).*) t',
        bool_or(a.atttypid = ANY (_typ))
    FROM (
        SELECT
            a.atttypid,
            quote_ident(attname) AS col,
            attname
        FROM
            pg_catalog.pg_attribute a
        WHERE
            a.attrelid = TG_RELID
            AND a.attnum >= 1
            AND NOT a.attisdropped) a;
        -- RAISE NOTICE '_sql: %', _sql;
    IF _found THEN
        EXECUTE _sql
        USING new INTO new;
    END IF;
        RETURN new;
END
$func$
LANGUAGE plpgsql;


/*
generic text trigger transform.
    for the specified table ($1),columns ($2)
    create trigger based on $3 trigger function.
    validate $3 is a trigger function not in pg_catalog, is visible to search_path
    validate $1,$2 do actually exists.
*/
CREATE OR REPLACE PROCEDURE generic_text_trigger_transform(regclass, text[], text)
    AS $func$
DECLARE
    stmt text;
    trg text;
    args text;
    _typ CONSTANT regtype[] := '{text,bpchar,name, varchar}';
    _sql    text;
BEGIN

    IF  $1 IS NULL OR $2 IS NULL OR $3 IS NULL THEN
        RAISE EXCEPTION '$1, $2, $3 all should not be null!';
    END IF;

    IF  NOT EXISTS(
        SELECT
        FROM        pg_catalog.pg_proc pp
        LEFT JOIN   pg_catalog.pg_namespace n ON n.oid = pp.pronamespace
        WHERE   pp.proname   =  $3
            AND pg_catalog.pg_function_is_visible(pp.oid)
            AND n.nspname::text <> 'pg_catalog'
            AND pg_catalog.pg_get_function_result(pp.oid) = 'trigger'
        )
        THEN
        RAISE EXCEPTION '$3 should be a function that not in pg_catalog schema and return trigger and is visible to search_path';
    END IF;

    IF  NOT EXISTS(
        SELECT  
        FROM    pg_attribute    pa
        JOIN    pg_class        pc  
        ON      pc.oid  = pa.attrelid
        WHERE   pa.attrelid = $1   
        AND     pa.attnum > 0 
        AND     pa.attisdropped IS FALSE        
        AND     pc.relpersistence   = 'p'
        AND     pc.relkind in ('r','m','p')     --regular table or materialized view or partitioned table.
        AND     pa.attgenerated    = ''         --should not touch generated columns
        AND     pa.atttypid     = ANY(_typ)
        HAVING array_agg(attname::text) @> $2
        ) THEN
            
        RAISE EXCEPTION 'upper_this exception! because one or more of the following cases yield true:
                        * not all columns($2) in $1
                        * $1 table not exists
                        * $1 is not in (regular table, materialized view, partitioned table)
                        * $1 is not permanent table
                        * one of $2 is generated columns
                        * $2 type <> ANY{text,bpchar,name, varchar}';                        
    END IF;

    trg :=  $1::text  ||    '_' ||$3 || '_' || (
    SELECT
        string_agg((x), '_')
    FROM
        unnest($2) sub (x));

    IF EXISTS (
        SELECT  FROM    pg_trigger
        WHERE   tgrelid = $1    
        AND     tgname = trg)   THEN    
            RAISE EXCEPTION 'trigger % on % already exists!',trg, $1;
    END IF;

    args := '(' || (
        SELECT  string_agg(quote_literal(x), ', ')
        FROM    unnest($2) sub (x)) || ')';

    stmt := format('
            CREATE TRIGGER  %s
            BEFORE INSERT OR UPDATE ON ', trg) || $1::text|| ' FOR EACH ROW '
            ' EXECUTE PROCEDURE ' || $3 || ' ' || args;
    -- RAISE NOTICE 'stmt:%', stmt;
    EXECUTE stmt;        
END
$func$
LANGUAGE plpgsql;


comment on function  public.strip is $$
trigger based function to strip leading and trailing white spaces.
references:
    https://jkorpela.fi/chars/spaces.html
    https://dbfiddle.uk/IcNrq3O1
    https://stackoverflow.com/questions/22699535/trim-trailing-spaces-with-postgresql/22701212#22701212
    https://stackoverflow.com/questions/63302656/remove-all-unicode-space-separators-in-postgresql/63311776#63311776
    https://en.wikipedia.org/wiki/Whitespace_character
    https://www.postgresql.org/docs/current/functions-string.html
$$;

comment on PROCEDURE generic_text_trigger_transform is $$
generic text trigger transform.
    for the specified table ($1),columns ($2)
    create trigger based on $3 trigger function.
    validate $3 is a trigger function not in pg_catalog, is visible to search_path
    validate $1,$2 do actually exists.
$$;

COMMIT;

------------------------------------------------------------------------
--test 

--validate comment is there.
SELECT length(description) > 400 as comment_there 
FROM    all_comment 
WHERE    name = 'strip';

BEGIN;
DROP TABLE  IF EXISTS t12 CASCADE;
DROP VIEW   IF EXISTS spaces CASCADE;

CREATE TABLE t12 (
    tid int GENERATED BY DEFAULT AS IDENTITY,
    chr_d int,
    in_posix_space_class bool,
    src text,
    src_v1 text,
    src_v2 text
);

CREATE OR REPLACE VIEW spaces AS
SELECT
    chr_d,
    chr(chr_d) ~ '\s' AS in_posix_space_class,
    chr(chr_d) || ' test my string    ' || chr(chr_d) AS src,
    length(chr(chr_d) || ' test my string    ' || chr(chr_d)) AS src_len
FROM (
    SELECT
        unnest('{9,32,160,5760,6158,8239,8287,8288,12288,65279}'::int[])
    UNION ALL
    SELECT
        generate_series(8192, 8202) AS dec -- UNICODE "Spaces"
    UNION ALL
    SELECT
        generate_series(8203, 8207) AS dec -- First 5 space-like UNICODE "Format characters"
) t (chr_d);
COMMIT;

---- test insert on src column.
BEGIN;
call generic_text_trigger_transform('t12',array['src'],'strip');

INSERT INTO t12 (chr_d, in_posix_space_class, src)
SELECT  chr_d,in_posix_space_class,src  
FROM    spaces;

SELECT  count(*)    as src_should_be_zero
FROM    t12
where   length(src) <> 14
and     src IS NOT NULL;

ROLLBACK;

    

--test update on column src_v2.
BEGIN;
call generic_text_trigger_transform('t12',array['src_v2'],'strip');

INSERT INTO t12 (chr_d, in_posix_space_class, src)
SELECT    chr_d,  in_posix_space_class,   src
FROM    spaces;

UPDATE  t12 SET src_v2 = src;

SELECT  count(*)    as src_v2_should_be_zero
FROM    t12
where   length(src_v2) <> 14
and     src_v2 IS NOT NULL;

ROLLBACK;


--test update on column src_v1, src_v2.
BEGIN;
call generic_text_trigger_transform('t12',array['src_v1','src_v2'],'strip');

INSERT INTO t12 (chr_d, in_posix_space_class, src)
SELECT  chr_d,in_posix_space_class,src  
FROM    spaces;

UPDATE  t12 SET src_v1 = src,src_v2 = src;

SELECT  count(*)    as src_v1_should_be_zero
FROM    t12
where   length(src_v1) <> 14
and     src_v1 IS NOT NULL;

SELECT  count(*)    as src_v2_should_be_zero
FROM    t12
where   length(src_v2) <> 14
and     src_v2 IS NOT NULL;

ROLLBACK;

--clean up.
DROP TABLE IF EXISTS t12 CASCADE;
DROP VIEW IF EXISTS spaces;

