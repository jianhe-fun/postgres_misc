--1.  move deleted records to another table.
create or replace function emp_archive()
    returns trigger as
$$
begin
    insert into emp_archive values(OLD.empid,OLD.name,
                                   OLD.department,OLD.salary,
                                   OLD.emp_date_id,OLD.misc,current_timestamp);
    return OLD;
end
$$ language plpgsql;

create trigger t_emp_archive
    BEFORE DELETE ON emp
    FOR EACH ROW
EXECUTE PROCEDURE emp_archive();

--disable trigger
alter table emp disable trigger t_emp_archive;

--2. let delete on view, so delete on view will invoke trigger on view.
create or replace function archive_test()
    returns trigger as
$$
begin
    execute format('update %I set misc = ''hello'' where empid = $1',TG_TABLE_NAME)
        using OLD.empid;
    return OLD;
end
$$ language plpgsql;

create trigger emp_archive_test INSTEAD OF DELETE ON emp_view
    FOR EACH ROW EXECUTE PROCEDURE archive_test();

create view emp_view as select * from emp;
delete from emp_view where emp_view.empid = 1;