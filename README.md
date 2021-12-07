# plpgsql
PostgreSQL plpgsql demo
https://stackoverflow.com/questions/7945932/how-to-return-result-of-a-select-inside-a-function-in-postgresql/7945958#7945958

https://stackoverflow.com/questions/7462322/the-forgotten-assignment-operator-and-the-commonplace


## DO command vs. PL/pgSQL function
> The DO command does not return rows. You can send NOTICES or RAISE other messages (with language plpgsql) or you can write to a (temporary) table and later SELECT from it to get around this