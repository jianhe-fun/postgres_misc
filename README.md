# plpgsql
# why [PLPGSQL Function](https://stackoverflow.com/questions/7510092/what-are-the-pros-and-cons-of-performing-calculations-in-sql-vs-in-your-applica/7518619#7518619)     
PostgreSQL plpgsql demo
https://stackoverflow.com/questions/7945932/how-to-return-result-of-a-select-inside-a-function-in-postgresql/7945958#7945958

https://stackoverflow.com/questions/7462322/the-forgotten-assignment-operator-and-the-commonplace


## DO command vs. PL/pgSQL function
> The DO command does not return rows. You can send NOTICES or RAISE other messages (with language plpgsql) or you can write to a (temporary) table and later SELECT from it to get around this.           

>But really, create a (plpgsql) function instead, where you can define a return type with the RETURNS clause or OUT / INOUT parameters and return from the function in various ways.

> If you don't want a function saved and visible for other connections, consider a "temporary" function, which is an undocumented but well established feature.

## RECORD HOLD A SINGLE ROW OF DATA.
_______________________
### Cannot use transaction statements like SAVEPOINT, COMMIT or ROLLBACK in a function.
>  since functions are not procedures that are invoked with CALL, you cannot do that in functions.
The BEGIN that starts a block in PL/pgSQL is different from the SQL statement BEGIN that starts a transaction.
any error within the plpgsql function body will lead to a ROLLBACK that also undoes any of the previous statements in the function body.
------------------------
### PLPGSQL function INOUT paramters, returns variable,declare variables
should be distinguish with the BODY query related
columns names.  
