
--with plpgsql, using insert to multi table once at a time.
create or replace function public.create_user_with_login(
    _email text,_password text,_firstname text=null, _surname text = null
) returns setof public.users language plpgsql as
$func$
begin
    return query
        with u as (
            insert into public.users(firstname, surname, email)
                values(_firstname,_surname,_email)
                returning *
        )
           ,a as (insert into accounts(user_id) select u.user_id from u)
            table u;
end
$func$;
select * from public.create_user_with_login('test@test.com','asjk','alison','bailey');

