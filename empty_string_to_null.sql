/* https://stackoverflow.com/questions/10621897/replace-empty-strings-with-null-values?answertab=modifieddesc#tab-top
 * get all the column that data type is string.
 *   and column that is not null.
 */

select quote_ident(attname) as colname
from pg_attribute
where attrelid = 't4'::regclass --t4 refer to the query table.
and attnum >1  and not attisdropped and  not attnotnull
and  atttypid::regtype
         =  any( string_to_array('text, bpchar,varchar',',') ::regtype[]);

--data init
begin;
CREATE TABLE t4(id int, txt1 text, txt2 varchar, txt3 varchar(10), txt4 char(17) NOT NULL);
INSERT INTO t4 VALUES (1,'','','',''), (2, null,'foo','','bar'), (3, 'foo', '', 'bar','');
INSERT INTO t4 VALUES (4,' ','   ','    ','     ');
commit;


/*convert empty string '' to null.

    intended execute statement: update t4 set txt1 = nullif(txt1,''),
        txt2 = nullif(txt2,'')  where t4.txt1 = '' or t4.txt2 = '';

  */
create or replace function f_empty_text_to_null
    (_tbl regclass)
returns void language plpgsql as
    $body$
    declare _typ CONSTANT regtype[] := '{text, bpchar, varchar}';
        _sql text;
    begin
         _sql := 'UPDATE ' || _tbl ||
        E'\nSET  ' || string_agg(format('%1$s = NULLIF(%1$s,'''')', col), E'\n   ,')
        || E'\nWHERE ' || string_agg(col || ' = ''''', ' OR ')
    from
        (select quote_ident(attname) as col
        from pg_attribute
        where attrelid = _tbl
        and attnum >= 1  and not attisdropped and  not attnotnull
        and  atttypid =  any(_typ)  order by attnum) sub;
    raise notice '%', _sql;
    end
    $body$;