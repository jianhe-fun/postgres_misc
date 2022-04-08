--basically a trigger:  in a period a dept's salary have budget limits, you can delete/update/insert emp_salary_into
-- but you cannot cross the budget limits set for specific (dept, budgetmonth).

-- https://stackoverflow.com/questions/22746741/trigger-for-checking-a-given-value-before-insert-or-update-on-postgresql/58951519#58951519
--https://www.google.com/search?q=stackoverflow+postgresql+create+a++trigger++set+a+limits+site:stackoverflow.com&client=firefox-b-d&sxsrf=APq-WBtIywE-7duP1dnNdXo9uA4QzDJTFw:1649425447157&sa=X&ved=2ahUKEwjJvfHOzIT3AhWaRmwGHVHSA8QQrQIoBHoECAMQBQ&biw=1280&bih=531&dpr=2


--so far it just works. but there still have problems need to solve.

--another question how to design it. since now dept_budget set the dept_id primary key. but for another month we
--obvious will be the same deptid, deptname.

--one question is exception not invoke. insert/update will just say insert/update 0,0 how to make error says
--that you cannot do it. since you exceeded your limits.
--I guess performance would be an issue. since your insert one, your compute all, it's a more efficient way to do it.


begin;
create table dept_budget(deptid bigint ,
deptname text not null, budget_month date not null, budget numeric not null, primary key (deptid));

create table emp_salary_info(
empid bigint,
name text not null,
salary numeric not null,
deptid bigint references dept_budget(deptid),
salary_period date, primary key (empid, salary_period));
insert into dept_budget values(1,'finance','2022-01-01',1000);
insert into dept_budget values(2,'marketing', '2022-01-01', 1100);
insert into emp_salary_info values(1,'jerry', 200,1, '2022-01-01');
insert into emp_salary_info values(2,'seinfeld', 300,1,'2022-01-01');
insert into emp_salary_info values(3,'george', 301,2,'2022-01-01');
commit;


alter table emp_salary_info drop constraint  emp_salary_info_pkey;
alter table emp_salary_info add primary key (empid, salary_period);
alter table dept_budget drop constraint  dept_budget_pkey ;
alter table dept_budget add primary key (deptid, budget_month);

create or replace function f_trigger_emp_salary_info_in()
returns trigger as
$$
    declare r  record;
    begin
        for r in
        select a.deptid, budget, sum_total from
        (select  deptid, sum(salary) sum_total from emp_salary_info group by 1 ) a
        join  dept_budget d using (deptid)
        loop
            if r.budget >  r.sum_total then
            else RAISE EXCEPTION '% will not insert', NEW.name;
            end if;
        end loop;
        return null;
    end;
$$ language plpgsql;


create or replace trigger trigger_in_emp_salary_info
BEFORE INSERT ON emp_salary_info FOR EACH ROW
execute procedure f_trigger_emp_salary_info_in();

create or replace  trigger trigger_up_emp_salary_info
BEFORE UPDATE ON emp_salary_info FOR EACH ROW
execute procedure f_trigger_emp_salary_info_in();





--will fail.
insert into emp_salary_info values(4,'elaine', 501,1,'2022-01-01');
--this one also will fail.
update emp_salary_info set salary  = 801 where empid = 2;

select e.deptid,d.budget_month, e.sum_total,d.budget from
(select  deptid, salary_period, sum(salary) sum_total from emp_salary_info group by 1,2) e
join  dept_budget d on d.deptid = e.deptid and d.budget_month = e.salary_period;

table emp_salary_info;
table dept_budget;
drop table emp_salary_info cascade ;
drop table dept_budget cascade;

drop trigger trigger_up_emp_salary_info on emp_salary_info;
drop trigger trigger_up_emp_salary_info on emp_salary_info;