---function was created in public schema. 
--tables to be deleted is in test schema.
/*  Format I: I treats the argument value as an SQL identifier,
    double-quoting it if necessary. 
It is an error for the value to be null (equivalent to quote_ident).
*/

CREATE OR REPLACE FUNCTION public.f_truncate_tables(_username text)
  RETURNS void AS
$func$
BEGIN
   -- dangerous, test before you execute!
  (SELECT 'TRUNCATE TABLE '
       || string_agg(format('%I.%I', schemaname, tablename), ', ')
       || ' CASCADE'
   FROM   pg_tables
   WHERE  tableowner = _username
   AND    schemaname = 'test'
   );
END
$func$ LANGUAGE plpgsql;

