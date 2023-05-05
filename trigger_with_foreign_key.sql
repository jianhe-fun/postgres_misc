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


BEGIN;
CREATE TABLE dept_budget (
    deptid bigint,
    deptname text NOT NULL,
    budget_month date NOT NULL,
    budget numeric NOT NULL,
    PRIMARY KEY (deptid)
);
CREATE TABLE emp_salary_info (
    empid bigint,
    name text NOT NULL,
    salary numeric NOT NULL,
    deptid bigint REFERENCES dept_budget (deptid),
    salary_period date,
    PRIMARY KEY (empid, salary_period)
);

INSERT INTO dept_budget
    VALUES (1, 'finance', '2022-01-01', 1000)
        , (2, 'marketing', '2022-01-01', 1100);
INSERT INTO emp_salary_info
    VALUES (1, 'jerry', 200, 1, '2022-01-01')
    ,(2, 'seinfeld', 300, 1, '2022-01-01')
    ,(3, 'george', 301, 2, '2022-01-01');
COMMIT;

ALTER TABLE emp_salary_info
    DROP CONSTRAINT emp_salary_info_pkey;

ALTER TABLE emp_salary_info
    ADD PRIMARY KEY (empid, salary_period);

ALTER TABLE dept_budget
    DROP CONSTRAINT dept_budget_pkey;

ALTER TABLE dept_budget
    ADD PRIMARY KEY (deptid, budget_month);

CREATE OR REPLACE FUNCTION f_trigger_emp_salary_info_in ()
    RETURNS TRIGGER
    AS $$
DECLARE
    r record;
BEGIN
    FOR r IN
    SELECT
        a.deptid,
        budget,
        sum_total
    FROM (
        SELECT
            deptid,
            sum(salary) sum_total
        FROM
            emp_salary_info
        GROUP BY
            1) a
    JOIN dept_budget d USING (deptid)
LOOP
    IF r.budget > r.sum_total THEN
    ELSE
        RAISE EXCEPTION '% will not insert', NEW.name;
    END IF;
END LOOP;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trigger_in_emp_salary_info
    BEFORE INSERT ON emp_salary_info
    FOR EACH ROW
    EXECUTE PROCEDURE f_trigger_emp_salary_info_in ();

CREATE OR REPLACE TRIGGER trigger_up_emp_salary_info
    BEFORE UPDATE ON emp_salary_info
    FOR EACH ROW
    EXECUTE PROCEDURE f_trigger_emp_salary_info_in ();

--will fail.
INSERT INTO emp_salary_info
    VALUES (4, 'elaine', 501, 1, '2022-01-01');

--this one also will fail.
UPDATE
    emp_salary_info
SET
    salary = 801
WHERE
    empid = 2;

SELECT
    e.deptid,
    d.budget_month,
    e.sum_total,
    d.budget
FROM (
    SELECT
        deptid,
        salary_period,
        sum(salary) sum_total
    FROM
        emp_salary_info
    GROUP BY
        1,
        2) e
    JOIN dept_budget d ON d.deptid = e.deptid
        AND d.budget_month = e.salary_period;

TABLE emp_salary_info;

TABLE dept_budget;

DROP TABLE emp_salary_info CASCADE;

DROP TABLE dept_budget CASCADE;

DROP TRIGGER trigger_up_emp_salary_info ON emp_salary_info;

DROP TRIGGER trigger_up_emp_salary_info ON emp_salary_info;

