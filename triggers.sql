--data init.
create table tbl(t_id bigserial primary key,txt text);

/*
    trigger function no input argument, returns trigger.
    after create trigger function then create trigger.
    the trigger will be execute alphabetically. trg_demo1 will be first executed, then trg_demo2.
 *
 */
begin;
create or replace  function trg_demo1()
returns trigger as
$func$
    declare _col_value  text;
        _col_name text := quote_ident(tg_argv[0]);
    begin
        /*
        NEW refer to before insert or update, the income record.
        NEW obviously is composite when multi columns.
        To access individual columns using NEW._col_name.
        */
        EXECUTE format('select ($1).%I::text',_col_name)
        USING NEW INTO _col_value;

        raise info 'This is a test: %', _col_value;
        raise info 'hello world';

        RETURN NEW;
    end
$func$ language plpgsql;

create or replace trigger demo1 before insert or update on tbl for each row execute procedure trg_demo1('txt');

create or replace function trg_demo2()
RETURNS trigger as
    $body$ declare _col_value text := to_json(NEW) ->> tg_argv[0];
    begin
    /*
    --It works. The value of NEW.txt is >>test102<<.
    In this context, the TG_ARGV[0] is the trigger function first input argument.
     Note that the function must be declared with no arguments
    even if it expects to receive some arguments specified in CREATE TRIGGER — such arguments are passed via TG_ARGV.

    */
    raise notice 'It works. The value of NEW.% is >>%<<.',TG_ARGV[0],_col_value;
    return NEW;
    end
    $body$ language plpgsql;

create or replace trigger demo2 before insert or update on tbl for each row execute procedure trg_demo2('txt');
commit ;


insert into tbl(txt) values ('test102');
