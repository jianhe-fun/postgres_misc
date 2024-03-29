
* **all_access.sql**. permission view for each (objects, role) in the current database. check the actual file for specific object and role.

* **all_analyze**. stored procedure automate manual analyze in case autovaccum don't analyze it yet.
* **all_bloat.sql**. table bloat estimation experiment. via view pg_stats or via pgstattuple_approx function. 

* **all_id.sql**. generally, some table have columns name as id. 2 functions. first one to evaulate existence table column name (~* id) value equal to x. Second one, returns rows (same data type as the table) where column name = x. 

* **all_index_bloat.sql**. index bloat estimation. Require superuser priviledge to read table pg_statistic.

* **all_comment.sql**. query comments for the most used objects in the database, like view, table, function etc.

* **all_select.sql**. show all the tables, views, materialized views that can be "SELECT" by public (every role in the cluster).

* **all_strip.sql**. Trigger function strip and procedure generic_text_trigger_transform. generic_text_trigger_transform(regclass, text[], text). $1, the trigger target table. $2 type text[], aggregated column names in $1 meet string data type criteria. $3,trigger function. procedure generic_text_trigger_transform is  generic, any kind of one to one text transform(like upper) can be applied.In here trigger function "strip" will strip specified columns name(one or more) leading and trailing white spaces before insert or update on target table($1).
* **search_path_required.sql**. event trigger. newly created function must explict set the search_path, aslo function creator have "USAGE" privilege for at least one of the search_path's schema.

* **all_upper.sql** generic procedure generic_text_trigger_transform,triggers function upper_this. Newly created trigger will upper specified  columns in specified table before insert or update. generic_text_trigger_transform in all_strip.sql.

* **atleast1.sql** AFTER DELETE trigger on foreign key table, enforce at least one entry for each unique foreign key, after delete.

* **btree_walk.sql**  btree walk through, from root node to inner node to leaf node.

* table_create_require_primary_key.sql. Newly created table must explicit set primary key.
* **work_around_not_null.sql**. work around when not null constraint violated.
* **insert_passing_var.sql**.    using updateable view, trigger, passing variable to the insert operation. glue the logic {case when variable is x then do x end case}. into the trigger.
* **global_match.sql**. pattern match against multiple relations.
* **disallow_column_name_as_id.sql**. any of the following actions {create table, create materialized view, alter table, alter materialzied view} new relations column cannot be "id"

* **last_modified.sql** Update last_modified (timestamptz) value to now() every time insert/update on the corresponding row.

* [Why just use PL/pgSQL Function](https://stackoverflow.com/questions/7510092/what-are-the-pros-and-cons-of-performing-calculations-in-sql-vs-in-your-applica/7518619#7518619)      
* [PL/pgSQL feature demo](https://stackoverflow.com/questions/7945932/how-to-return-result-of-a-select-inside-a-function-in-postgresql/7945958#7945958)           
* https://stackoverflow.com/questions/7462322/the-forgotten-assignment-operator-and-the-commonplace
* record data type explanation: Identifies a function taking or returning an unspecified row type. source: https://www.postgresql.org/docs/current/datatype-pseudo.html                
*  `PERFORM  do_something(m.id) FROM    MyTable m WHERE   m.IsActive;`
* `Perform`  is the PL/pgSQL alternative for `select` for when you want throw.
away the return result.   
 You cannot use SELECT without a target in PL/pgSQL code. Replace it with `PERFORM` in those calls. 
* [Why you should just use text type](https://stackoverflow.com/questions/10758149/cast-produces-returned-type-character-varying-does-not-match-expected-type-char)
* [General RETURNING expression should be](https://stackoverflow.com/questions/40864464/postgresql-pgadmin-error-return-cannot-have-a-parameter-in-function-returning-s)             
* [Improve performance for order by with columns from many tables](https://dba.stackexchange.com/questions/112679/improve-performance-for-order-by-with-columns-from-many-tables/112680#112680) Multiple tables join then order by serval columns that belong to different table.     

## DO command vs. PL/pgSQL function
> The DO command does not return rows. You can send NOTICES or RAISE other messages (with language PL/pgSQL) or you can write to a (temporary) table and later SELECT from it to get around this.           
>But really, create a (PL/pgSQL) function instead, where you can define a return type with the RETURNS clause or OUT / INOUT parameters and return from the function in various ways.
> If you don't want a function saved and visible for other connections, consider a "temporary" function, which is an undocumented but well established feature.

## Cannot use transaction statements like SAVEPOINT, COMMIT or ROLLBACK in a function.
>  since functions are not procedures that are invoked with CALL, you cannot do that in functions.
The BEGIN that starts a block in PL/pgSQL is different from the SQL statement BEGIN that starts a transaction.
any error within the plpgsql function body will lead to a ROLLBACK that also undoes any of the previous statements in the function body.

## Expression Indexes 
>**IMMUTABLE** means "does not change" or "unchangeable". **What you must do to
> strictly avoid violating that rule is drop the function and everything that
> depends on it then re-create it and the indexes that use it.**                                            
> If you change an immutable function's behaviour then indexes based on the function are invalid. The server can't tell if the function's behaviour has  changed or not; you might just have replaced it with an optimized version that has identical behaviour in every respect. So it won't invalidate the indexes for you, though perhaps it should, since if your function's behaviour does differ you can get incorrect query results for queries based on the function. So if function changes, you need rebuild the index that based on that index.                     