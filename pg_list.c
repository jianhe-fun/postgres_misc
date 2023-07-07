/*
--compile and link it.
gcc -Wextra -I/home/jian/postgres/2023_05_25_beta5421/include/server -fPIC -c /home/jian/postgres_misc/pg_list.c
gcc -shared  -o /home/jian/postgres_misc/pg_list.so /home/jian/postgres_misc/pg_list.o

-- use it on SQL level.
CREATE OR REPLACE FUNCTION pg_scratch() RETURNS BOOL
AS '/home/jian/postgres_misc/pg_list', 'pg_scratch' LANGUAGE C STRICT PARALLEL SAFE;

select pg_scratch();

*/

#include "postgres.h"

#include "access/htup_details.h"
#include "access/relation.h"
#include "catalog/pg_am_d.h"
#include "catalog/namespace.h"
#include "catalog/pg_type.h"
#include "funcapi.h"
#include "mb/pg_wchar.h"
#include "miscadmin.h"
#include "port/pg_bitutils.h"
#include "storage/bufmgr.h"
#include "storage/checksum.h"
#include "storage/bufpage.h"
#include "utils/array.h"
#include "utils/builtins.h"
#include "utils/pg_lsn.h"
#include "utils/rel.h"
#include "utils/varlena.h"

PG_MODULE_MAGIC;
PG_FUNCTION_INFO_V1(pg_scratch);

Datum pg_scratch(PG_FUNCTION_ARGS)
{
    char *src   = "test16.public.a";    
    text *namlist    = cstring_to_text(src);
    
    List *tmp   = textToQualifiedNameList(namlist); /*template list*/
    ListCell *cell;                                 /* list iterator */

    elog(INFO,"list_length:%d",list_length(tmp));

    foreach(cell, tmp)
    {
        String *test  = (String *) lfirst(cell);
        elog(INFO,"1st string is |%s|", test->sval);
    }
    PG_RETURN_BOOL(true);
}
