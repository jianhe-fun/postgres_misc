/*
https://raw.gcithubusercontent.com/dverite/postgresql-functions/master/global_search/global_match.sql
https://dba.stackexchange.com/questions/117403/faster-query-with-pattern-matching-on-multiple-text-fields
    found out which column have ~* paattern. 
    if tables not specified then search all tables in schema( !~* ^pg_ and <> information_schema)
    since many of record will be matched, so set the pattern min length to 5.
    aslo now it's not as efficient as it looks, say you have two text columns, then you need do a seq scan
    on that table twice.

    todo. make table only once, even if there are multiple column match it.
*/