
/*  Procedures do not return a function value;
hence CREATE PROCEDURE lacks a RETURNS clause. 
 However, procedures can instead return data to their callers via output parameters.
*/
--Since return void, It's more about create update, delete DML. rather than select.
--Since select must return something  rather than nothing. 
CREATE  OR REPLACE  PROCEDURE c_foo()
AS $$
  CREATE temp TABLE foo (fooid int, bar text);
$$ LANGUAGE sql;

--Call the procedure. 
CALL c_foo();
