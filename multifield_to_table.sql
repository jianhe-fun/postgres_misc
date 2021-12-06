 --two column, two rows data  convert to an four column table  via plpgsql function.
 --feed the data.
begin;
CREATE TABLE users(user_id int, school_id int, name text);
insert into users values (1, 10,'alice')
,(5, 10,'boy')
,(13, 10,'cassey')
,(17, 10,'delores')
,(4, 11,'elaine');
commit;

CREATE OR REPLACE FUNCTION 
    get_object_fields2(_school_id int)
  RETURNS TABLE (user1_id   int
               , user1_name text
               , user2_id   int
               , user2_name text) 
               LANGUAGE plpgsql AS 
$func$
DECLARE countu integer;
BEGIN
    countu := (
        select count(*) from users where school_id = _school_id);
    IF countu >= 2 THEN
        RETURN QUERY  --will only cross join two rows to an one row table. 
            with a as (
            select u1.user_id,
                u1.name from  users u1 
                where school_id = _school_id 
                    order by user_id limit 1),
            b as(
                select u2.user_id,u2.name from users u2 
                where school_id = _school_id 
                    order by user_id limit 1 offset 1 )
            select * from a  cross JOIN b;
    elseif countu = 1 then
    return query --return one rows, column name duplicate once, row data duplicate once. 
      select u1.user_id, u1.name,u1.user_id, u1.name 
        from  users u1 where school_id = _school_id; 
    else --school_id yield no rows.
        RAISE EXCEPTION 'not found'; 
    end if;
END
$func$;
