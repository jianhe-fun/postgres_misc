--plpgsql procedure to easy create new user.
create or replace procedure new_users(IN myuser text, IN mypass text)
    language plpgsql as
$$
BEGIN
    IF NOT EXISTS (SELECT from pg_catalog.pg_roles where rolname = myuser) THEN
        EXECUTE format(
                'create user %I with login nosuperuser createdb createrole noreplication password %L'
            ,myuser,mypass
            );
        raise notice 'create new user: %!',myuser;
    else raise notice 'User % already exists!',myuser;
    end if;
end
$$;