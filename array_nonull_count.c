/*
    array_nonull_count.c
    
    #### replace to your local include dir, c file, so file, o file.
    gcc -I/home/jian/postgres/2023_05_25_beta5421/include/server -fPIC -c /home/jian/Desktop/regress_pgsql/array_nonull_count.c
    gcc -shared  -o /home/jian/Desktop/regress_pgsql/array_nonull_count.so /home/jian/Desktop/regress_pgsql/array_nonull_count.o
*/
#include "postgres.h"

#include "utils/builtins.h"
#include "utils/array.h"
#include "utils/numeric.h"
#include "utils/datetime.h"
#include "utils/date.h"
#include "utils/timestamp.h"
#include "utils/timeout.h"
#include "utils/pg_lsn.h"
#include "funcapi.h"
#include "utils/lsyscache.h"
#include "utils/fmgrprotos.h"

PG_MODULE_MAGIC;
PG_FUNCTION_INFO_V1(array_nonull_count);

Datum
array_nonull_count(PG_FUNCTION_ARGS)
{
    ArrayType  *arr;
    Datum      *type_oids;
    Oid		    basetype;
    int		    nelements;
    int16	    typlen;
    bool	    typbyval;
    char	    typalign;
    bool       *typnullflag;
    int		    i;
    int		    nullcnt         = 0;
    int		    non_nullcnt;

    arr = PG_GETARG_ARRAYTYPE_P(0);
    if (PG_ARGISNULL(0))
        	ereport(ERROR, (errmsg("only for non null arrays.")));

    //This requirement could probably be lifted pretty easily:
    if (ARR_NDIM(arr) == 0)
	        ereport(ERROR, (errmsg("empty array not allowed")));
    else if (ARR_NDIM(arr) > 1)
	        ereport(ERROR, (errmsg("One-dimesional arrays are required")));

    //actual data pointer.
	type_oids = (Datum *) ARR_DATA_PTR(arr);
    basetype = ARR_ELEMTYPE(arr);

    get_typlenbyvalalign(basetype, &typlen, &typbyval, &typalign);
    nelements = ArrayGetNItems(ARR_NDIM(arr), ARR_DIMS(arr));

    //Extract the array contents(as Datum objects).
	deconstruct_array(arr, basetype, typlen, typbyval, typalign, &type_oids, &typnullflag, &nelements);

    for (i = 0; i < nelements; i++)
    {
        if (typnullflag[i])
        {
            nullcnt++;
            continue;
        }
    }

    non_nullcnt = nelements - nullcnt;           
    if (non_nullcnt == 0)
        PG_RETURN_NULL();
    else
        PG_RETURN_DATUM(non_nullcnt);                
}
