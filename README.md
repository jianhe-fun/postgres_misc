# plpgsql
PostgreSQL plpgsql demo
https://stackoverflow.com/questions/7945932/how-to-return-result-of-a-select-inside-a-function-in-postgresql/7945958#7945958

https://stackoverflow.com/questions/7462322/the-forgotten-assignment-operator-and-the-commonplace


## DO command vs. PL/pgSQL function
> The DO command does not return rows. You can send NOTICES or RAISE other messages (with language plpgsql) or you can write to a (temporary) table and later SELECT from it to get around this.           

>But really, create a (plpgsql) function instead, where you can define a return type with the RETURNS clause or OUT / INOUT parameters and return from the function in various ways.

> If you don't want a function saved and visible for other connections, consider a "temporary" function, which is an undocumented but well established feature.

## RECORD HOLD A SINGLE ROW OF DATA.