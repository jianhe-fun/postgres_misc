
BEGIN;

DROP FUNCTION IF EXISTS public.strip CASCADE;

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

    IF  argstr is null then
        RAISE EXCEPTION 'triggers based on strip function require one or more arguments.';
    END IF;

    IF NOT argstr <@ (
        SELECT  array_agg(attname::text)
        FROM    pg_catalog.pg_attribute a
        WHERE   a.attrelid = TG_RELID AND a.attnum >= 1 AND NOT a.attisdropped) THEN
            RAISE EXCEPTION 'triggers based on strip function require one or more arguments.';
    END IF;

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


CREATE OR REPLACE PROCEDURE sanitize_col_spaces (regclass, text[])
    AS $func$
DECLARE
    stmt text;
    trg text;
    args text;
BEGIN
    IF  NOT EXISTS(
        SELECT  array_agg(attname::text) @> $2
        FROM    pg_attribute    pa
        JOIN    pg_class        pc  
        ON      pc.oid  = pa.attrelid
        WHERE   pa.attrelid = $1   
        AND     pa.attnum > 0 
        AND     pa.attisdropped IS FALSE
        AND     pc.relkind in ('r','m','p')
        HAVING array_agg(attname::text) @> $2
        ) THEN
            RAISE EXCEPTION 'specified text column names not in the $1.'
                            'or $1 relation not exists, or $1 is not regular table.';
    END IF;
    trg := 'strip_' || $1::text || '_' || (
        SELECT  string_agg((x), '_')
        FROM    unnest($2) sub (x));
    
    IF EXISTS (
        SELECT  FROM    pg_trigger
        WHERE   tgrelid = $1    AND tgname = trg)   THEN    
            RAISE EXCEPTION 'trigger % on % already exists!',trg, $1;
    END IF;

    args := '(' || (
        SELECT
            string_agg(quote_literal(x), ', ')
        FROM
            unnest($2) sub (x)) || ')';
    stmt := format('
            CREATE TRIGGER  %s
            BEFORE INSERT OR UPDATE ON ', trg) || $1::text|| ' FOR EACH ROW '
            ' EXECUTE PROCEDURE strip ' || args;
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

comment on PROCEDURE sanitize_col_spaces is $$
create trigger for specified table $1(regclass), specified columns $2(text[]).
If table or or columns  not exists then raise exception.
$$;

COMMIT;
------------------------------------------------------------------------
--test 

--validate comment is there.
SELECT  *   FROM    all_comment WHERE    name = 'strip';



DROP TABLE IF EXISTS t12 CASCADE;

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


call sanitize_col_spaces('t12',array['bullshit']);
/*
ERROR:  specified text column names not in the $1. or $1 relation not exists
CONTEXT:  PL/pgSQL function sanitize_col_spaces(regclass,text[]) line 11 at RAISE
*/

---- test insert on src column.
BEGIN;
call sanitize_col_spaces('t12',array['src']);

INSERT INTO t12 (chr_d, in_posix_space_class, src)
SELECT  chr_d,in_posix_space_class,src  FROM    spaces  ORDER BY    1   LIMIT 1;

INSERT INTO t12 (chr_d, in_posix_space_class, src)
SELECT  chr_d,in_posix_space_class,src
FROM    spaces  ORDER BY    1 offset 1;

SELECT    length(src),  *   FROM    t12;
ROLLBACK;

    

--test update on column src_v2.
BEGIN;
call sanitize_col_spaces('t12',array['src_v2']);

INSERT INTO t12 (chr_d, in_posix_space_class, src)
SELECT    chr_d,  in_posix_space_class,   src
FROM    spaces;

UPDATE  t12 SET src_v2 = src;

TABLE t12;
ROLLBACK;

--test update on column src_v1, src_v2.
BEGIN;
call sanitize_col_spaces('t12',array['src_v1','src_v2']);

INSERT INTO t12 (chr_d, in_posix_space_class, src)
SELECT  chr_d,in_posix_space_class,src  FROM    spaces;

SELECT  *,  length(src) FROM    t12;

UPDATE  t12 SET src_v1 = src,src_v2 = src;
    
SELECT  *,length(src),length(src_v1),length(src_v1) = length(src_v2)    FROM    t12;

ROLLBACK;

--clean up.
DROP TABLE IF EXISTS t12 CASCADE;
DROP FUNCTION IF EXISTS public.strip CASCADE;
DROP VIEW IF EXISTS spaces;
DROP PROCEDURE IF EXISTS sanitize_col_spaces;
