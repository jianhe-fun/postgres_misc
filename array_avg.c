/*
    array_avg.c

    #### replace to your local include dir, c file, so file, o file.
    gcc -I/home/jian/postgres/2023_05_25_beta5421/include/server -fPIC -c /home/jian/Desktop/regress_pgsql/array_avg.c
    gcc -shared  -o /home/jian/Desktop/regress_pgsql/array_avg.so /home/jian/Desktop/regress_pgsql/array_avg.o
*/

#include "postgres.h"

#include "utils/builtins.h"
#include "utils/array.h"
#include "utils/numeric.h"
#include "funcapi.h"
#include "utils/lsyscache.h"
#include "utils/fmgrprotos.h"
#include "utils/timestamp.h"

PG_MODULE_MAGIC;
PG_FUNCTION_INFO_V1(array_avg);

Datum
array_avg(PG_FUNCTION_ARGS)
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
    bool	    resisnull = true;
    int		    nullcnt         = 0;
    int		    non_nullcnt     = 0;
    int		    ndim;
    Datum       countd,
                sumd;

    arr = PG_GETARG_ARRAYTYPE_P(0);
    if (PG_ARGISNULL(0))
        	ereport(ERROR, (errmsg("only for non null arrays.")));

    //This requirement could probably be lifted pretty easily:
    ndim = ARR_NDIM(arr);
    if (ndim == 0)
	        ereport(ERROR, (errmsg("empty array not allowed")));
    else if (ndim > 1)
	        ereport(ERROR, (errmsg("One-dimesional arrays are required")));


    //actual data pointer.
	type_oids = (Datum *) ARR_DATA_PTR(arr);
    basetype = ARR_ELEMTYPE(arr);

    get_typlenbyvalalign(basetype, &typlen, &typbyval, &typalign);
    nelements = ArrayGetNItems(ARR_NDIM(arr), ARR_DIMS(arr));

    //Extract the array contents(as Datum objects).
	deconstruct_array(arr, basetype, typlen, typbyval, typalign, &type_oids, &typnullflag, &nelements);
    
    switch (basetype)
    {    
        case INT8OID:
            sumd = DirectFunctionCall1(int8_numeric, 0);

            for (i = 0; i < nelements; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                sumd = DirectFunctionCall2(numeric_add, DirectFunctionCall1(int8_numeric, type_oids[i]), sumd);
            }

            non_nullcnt = nelements - nullcnt;           
            countd = NumericGetDatum(int64_to_numeric(non_nullcnt));

            if (non_nullcnt == 0)
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(DirectFunctionCall2(numeric_div,sumd, countd));
                        
        case INT4OID:
            sumd = DirectFunctionCall1(int8_numeric, 0);

            for (i = 0; i < nelements; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                sumd = DirectFunctionCall2(numeric_add, DirectFunctionCall1(int4_numeric, type_oids[i]), sumd);
            }
            non_nullcnt = nelements - nullcnt;

            countd = NumericGetDatum(int64_to_numeric(non_nullcnt));

            if (non_nullcnt == 0)
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(DirectFunctionCall2(numeric_div,sumd, countd));

        case INT2OID:
            sumd = DirectFunctionCall1(int8_numeric, 0);

            for (i = 0; i < nelements; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                sumd = DirectFunctionCall2(numeric_add, DirectFunctionCall1(int2_numeric, type_oids[i]), sumd);
            }
            non_nullcnt = nelements - nullcnt;

            countd = NumericGetDatum(int64_to_numeric( non_nullcnt));

            if (non_nullcnt == 0)
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(DirectFunctionCall2(numeric_div,sumd, countd));   

        case NUMERICOID:
            sumd = DirectFunctionCall1(int8_numeric,0);
            for (i = 0; i < nelements; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                sumd = DirectFunctionCall2(numeric_add, type_oids[i], sumd);
            }
            non_nullcnt = nelements - nullcnt;
            countd = NumericGetDatum(int64_to_numeric( non_nullcnt));

            if (non_nullcnt == 0)
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(DirectFunctionCall2(numeric_div,sumd, countd));

        case INTERVALOID:
            sumd    =   DirectFunctionCall6(make_interval,0,0,0,0,0,0);
    
            for (i = 0; i < nelements; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                sumd = DirectFunctionCall2(interval_pl, type_oids[i],sumd);
            }
            
            non_nullcnt = nelements - nullcnt;
            countd = Float8GetDatum(non_nullcnt);

            if (non_nullcnt == 0)
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(DirectFunctionCall2(interval_div,sumd, countd));

        default:
            ereport(ERROR, (errmsg("allowed data type int2, int4, int8, numeric, interval")));                
    }
}
