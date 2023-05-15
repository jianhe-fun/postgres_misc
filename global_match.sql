/*

TODO how many time seq scan this function did a relation. how to track it via procedure or other simple way.
https://raw.githubusercontent.com/dverite/postgresql-functions/master/global_search/global_match.sql
https://dba.stackexchange.com/questions/117403/faster-query-with-pattern-matching-on-multiple-text-fields
    found out which relations ~* pattern. 
    * each pattern should be at least 4 chars. can have more than one pattern. matach any of the specified patterns.
    * flags/options: one or more flags listed in manual table. default is new line "n", so it will macth line by line.
    * if schema not specified then fall back to public schema. if specified, then all the schemas must exists.
    * if tables not specified then all table in the specified schema. tables argument can be not exists in the database
    * function execution role have "select" privilege to the whole being searched tables (not partial column select privilege)
    * target relation schemas criteria {exclude ^pg, information_schema}. default public.
    * target relation kind: only regular table and materialzied view. 
    * target table columns data type is in string category.
    * debug option. 
    * limit number of matches per ctid rows.  default off. if specified, then limit matched result.
    * target tables range(one more tables, all tables in a schema, multiple tables in multiple schemas}
    * if not a single target table exists then raise exceptuion.
    * returns table. (tid,text,text,bigint)
*/

drop function if exists public.global_match;

create or REPLACE function public.global_match(
        pattern text
        ,flags  text default ''
        ,schemas    text[]  default  '{public}'
        ,tables     text[]  default  '{}'
        ,limits     integer default  NULL
        ,debug      bool    default false
        )
returns table(ctid tid, rel text, matched text,sno bigint) LANGUAGE plpgsql set search_path from current AS
$$
DECLARE 
        _patterns   text[];             --pattern matching text array
        x           text    default ''; --for each text variable
        s           text    default ''; --temp var for hold pattern
        _flags       text[]    default '{"",b,c,e,i,m,n,p,q,s,t,w,x,g}';    
        target_rels regclass[]; --final target relations regclass[]
        invalid_flags   text[]; --for printing out invalid pattern matching flags.
        invalid_schemas text[]; --all invalid target schemas
        valid_schemas   text[]; --all valid target schemas
        tmp             text;   --for concatenate sql query
        tmp1             text;  --for concatenate sql query
        tmp2             text;  --for concatenate sql query
        tmp3             text;  --for concatenate sql query
        sub1             text;  --for concatenate sql query
        sub2             text;  --for concatenate sql query
        target          regclass;   --for loop variable.
        stmt           text;
begin

    if  left($1,1) = '#' 
        then 
            _patterns    := regexp_split_to_array(substring($1,2),'#');
    else
            _patterns    := regexp_split_to_array($1,'#');
    end if;
    FOREACH x IN ARRAY _patterns
    LOOP
        if(length(x) < 4) then 
            raise exception 'pattern word length should be at least 4 chars'; 
        end if;
        s := s || '|(.{0,10}?\w*?' || x || '.*?\M)';
    END LOOP;
    s   := substring(s,2); 

    if ($2 is null) then $2 := 'n'; end if;
    if strpos($2,'n') = 0 then $2 := $2 || 'n'; end if;
    select  array_agg(str) filter  (where array_position(_flags, str) is NULL) 
    into    invalid_flags
    from    regexp_split_to_table($2,'') str;
    
    if      invalid_flags is not null  
    then    raise exception 'invalid regular expression option: "%"', invalid_flags; 
    end if;

    if tables = '{}' OR (tables is null and schemas is not null) then
        select  array_agg(t.val) filter (
                                where to_regnamespace(t.val) is not null
                                and     t.val !~* '^pg_'                                
                                and     t.val <> 'information_schema'
                                )
                ,array_agg(t.val) filter (where to_regnamespace(t.val) is null )
        into    valid_schemas,invalid_schemas
        FROM   unnest(schemas) t(val);

        if invalid_schemas is not null then raise exception 'schemas % not exists', invalid_schemas; end if;
        
        select array_agg(to_regclass(sub.obj_schema || '.' || sub.obj_name)) into target_rels
        from
        (
            select  ac.obj_schema,ac.obj_name
            from    public.all_access  ac
            where   ac.privilege = 'SELECT'
            and     ac.kind in ('matview','table')
            and     ac.role = current_user
            and     ac.obj_schema = any(valid_schemas)
        ) sub
        where   exists
        (   select  
            from    pg_catalog.pg_attribute pa  
            where   pa.attrelid = to_regclass(sub.obj_schema || '.' || sub.obj_name)
            and     pa.attnum > 0
            and     pa.attisdropped is false
            and     pa.atttypid::regtype = any ('{text,bpchar,name, varchar}'::regtype[])
        );
    elsif ( tables is not null and tables <> '{}' and schemas is null)  then
        select      array_agg(to_regclass(sub.obj_schema || '.' || sub.obj_name)) 
        into        target_rels
        from
        (
            select  ac.obj_schema,ac.obj_name
            from    public.all_access  ac
            where   ac.privilege = 'SELECT'
            and     ac.kind in ('matview','table')
            and     ac.obj_name = ANY(tables)
            and     ac.role = current_user
        )sub
        where exists(
            select
            from    pg_catalog.pg_attribute pa  
            where   pa.attrelid = to_regclass(sub.obj_schema || '.' || sub.obj_name)
            and     pa.attnum > 0
            and     pa.attisdropped is false
            and     pa.atttypid::regtype = any ('{text,bpchar,name, varchar}'::regtype[])
            );
    elsif ((tables is null and schemas is null)
            OR (tables is null and schemas is null) 
            OR (tables is null and schemas is null)) then
            raise exception 'relation should not be null';
    else
        select array_agg(to_regclass(sub.obj_schema || '.' || sub.obj_name)) into target_rels
        from
        (
            select  ac.obj_schema,ac.obj_name
            from    public.all_access  ac
            where   ac.privilege = 'SELECT'
            and     ac.kind in ('matview','table')
            and     ac.role = current_user
            intersect
            select  u1, u2
            from
            unnest($3) u1,unnest($4) u2
        )   sub
        where   exists
        (
            select  
            from    pg_catalog.pg_attribute pa  
            where   pa.attrelid = to_regclass(sub.obj_schema || '.' || sub.obj_name)
            and     pa.attnum > 0
            and     pa.attisdropped is false
            and     pa.atttypid::regtype = any ('{text,bpchar,name, varchar}'::regtype[])
        );
    end if;

        if debug then
            raise notice 'all target relations:%',target_rels;
        end if;

        FOREACH target in  ARRAY target_rels loop
            if debug then 
                    raise notice '---------now scaning % estimate tuples %----------'
                    ,target
                    ,(select reltuples from pg_class where oid = target); 
            end if;

            SELECT string_agg(
                    (format(E'\n\t\tregexp_matches(%I,%L,%L) x',(a.attname),s,flags)) || attnum
                    ,E',')
                ,string_agg('unnest(x' || attnum || ')  x' || attnum,',')
                ,string_agg('x' || attnum,',')
            into    tmp,tmp1,tmp2
            FROM    pg_catalog.pg_attribute a
            WHERE   a.attrelid = target
            and     a.attnum > 0
            and     a.atttypid::regtype = any ('{text,bpchar,name, varchar}'::regtype[])
            and     a.attisdropped is false;
            sub1    := concat_ws('',E'\n\t\t(select   ctid,',tmp ,  E' from\n\t\t',target::text, E')sub1');
            sub2    := concat_ws('',E'\n\t(select  ctid,',tmp1,  E' from',sub1, E'\n\t)sub2');
            stmt    := concat_ws(''
                            ,'select * from '
                            ,'(select ctid, '
                            ,
                            (
                                select  quote_literal(relnamespace::regnamespace|| '.' || relname)
                                from    pg_class 
                                where   oid = target
                            )
                            ,', '
                            ,'f_concat_ws('''', '
                            ,tmp2
                            ,' ) as matched'
                            ,',row_number() OVER (ORDER BY ctid) as rn from '
                            ,sub2
                            ,E'\n\twhere length(f_concat_ws('''', '
                            ,tmp2
                            ,' )) <> 0'
                            ,E'\n) sub3 order by ctid'
                            );         
            if (limits > 0 and limits is not null) then
                stmt    := stmt || ' limit ' || limits;
            end if;
            if debug then raise notice E'final query:\n%',   stmt; end if;
            return query EXECUTE stmt;   
        END LOOP;
end
$$;

----------------test time.
select * from public.global_match('#HHHHxx#foo2','giiii','{public,pg_catalog}','{}',100,true);
select * from public.global_match('#GSAAAA#TKAAAA','gi','{public}','{}', 100,true);
select * from public.global_match('#HHHHxx#OOOOxx','gi','{public}','{}', 100,true);
select * from public.global_match('#HHHHxx#AAAAxx',NULL,'{public}','{}', 100,true);
select * from public.global_match('#HHHHxx#AAAAxx','','{public}','{tenk1}', 100,true);
select * from public.global_match('#HHHHxx#AAAAxx','','{public}','{}', 100,true);

--should yield an error
select * from public.global_match('#HHHHxx#VVVVxx','gz','{public}','{}',NULL,true);

---should_yield_zero
select count(*) as should_yield_zero from
(
    select * from public.global_match('#GSAAAA#TKAAAA','giiii','{public,pg_catalog}','{tenk1}', 100,false)
    except  all
    select * from public.global_match('#GSAAAA#TKAAAA','giiii',null,'{tenk1}', 100,false)
);

---should_yield_zero
select count(*) as should_yield_zero from
(
    select * from public.global_match('#HHHHxx#AAAAxx',NULL,'{public}','{tenk1}', 100,false)
    except all
    select * from public.global_match('#HHHHxx#AAAAxx','','{public}','{tenk1}', 100,false)
);

---should_yield_zero
select count(*) as should_yield_zero from
(
    select * from public.global_match('#HHHHxx','gi','{public}','{tenk1}',NULL,false)
    except all
    select * from public.global_match('HHHHxx','gi','{public}','{tenk1}',NULL,false)
) sub;

---should_yield_zero
select count(*) as should_yield_zero from
(
    select * from public.global_match('#HHHHxx','i','{public}','{tenk1}',NULL,false)
    except all
    select * from public.global_match('HHHHxx','gi','{public}','{tenk1}',NULL,false)
) sub;


