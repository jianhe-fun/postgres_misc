/*
    array_min.c
    https://stackoverflow.com/questions/16992339/why-is-postgresql-array-access-so-much-faster-in-c-than-in-pl-pgsql/16996606#16996606

    #### replace to your local include dir, c file, so file, o file.
    gcc -I/home/jian/postgres/2023_05_25_beta5421/include/server -fPIC -c /home/jian/Desktop/regress_pgsql/array_min.c
    gcc -shared  -o /home/jian/Desktop/regress_pgsql/array_min.so /home/jian/Desktop/regress_pgsql/array_min.o
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
PG_FUNCTION_INFO_V1(array_min);

Datum 
array_min(PG_FUNCTION_ARGS)
{
    ArrayType   *arr;
    Datum         *type_oids;
    Oid         basetype;
    int         nelements;
    int16       typlen;
    bool        typbyval;
    char        typalign;
    bool        *typnullflag;
    int         i;
    int		    nullcnt = 0;    /* init value for later doing arithmetic */
    int		    non_nullcnt;
    Datum       temp;

    arr =   PG_GETARG_ARRAYTYPE_P(0);

    if (PG_ARGISNULL(0))   
        PG_RETURN_NULL();
    
    // This requirement could probably be lifted pretty easily:
    if (ARR_NDIM(arr) != 1)
        ereport(ERROR, (errmsg("One-dimesional arrays are required")));

    //actual data pointer.
    type_oids   = (Datum *) ARR_DATA_PTR(arr);
    basetype    = ARR_ELEMTYPE(arr);

    if (basetype != INT2OID && basetype != INT4OID &&         
        basetype != INT8OID && basetype != FLOAT4OID && 
        basetype != FLOAT8OID && basetype != NUMERICOID &&
        basetype != DATEOID && basetype != TIMEOID &&
        basetype != TIMESTAMPOID && basetype != TIMESTAMPTZOID &&
        basetype != INTERVALOID && basetype != TIMETZOID       &&
        basetype != PG_LSNOID 
        )
        ereport(ERROR,
                (errmsg("allowed data type int2, int4,int8,float4"
                "float8,numeric,date,time,timestamp"
                "timestamptz,interval,timetz,pg_lsn;")));

    get_typlenbyvalalign(basetype, &typlen, &typbyval, &typalign);
    nelements      = ArrayGetNItems(ARR_NDIM(arr), ARR_DIMS(arr));
    if (nelements == 0) 
        PG_RETURN_NULL();
    
    // Extract the array contents (as Datum objects).
    deconstruct_array(arr,basetype,typlen,typbyval,typalign,&type_oids,&typnullflag,&nelements);
    
    temp    = type_oids[0];
    if (typnullflag[0])
        nullcnt++;

    switch (basetype)
    {    
        case INT2OID:
        case INT4OID:
        case INT8OID:
            for (i = 1; i < nelements; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if((bool) DirectFunctionCall2(int8lt,Int64GetDatum(type_oids[i]),temp))
                    temp  = type_oids[i];
            }        
            non_nullcnt = nelements - nullcnt;        
            if (non_nullcnt == 0)
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);
        
        case FLOAT4OID:
            for (i = 0; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(float4lt,type_oids[i],temp))
                    temp  = type_oids[i];                        
            }        
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case FLOAT8OID:
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(float8lt,type_oids[i],temp))
                    temp  = type_oids[i];                        
            }        
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case NUMERICOID:
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(numeric_lt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case DATEOID:
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(date_lt,type_oids[i],temp))
                    temp  = type_oids[i];
            }   
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case TIMEOID:
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(time_lt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case TIMESTAMPOID:
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(timestamp_lt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case TIMESTAMPTZOID:
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if ((bool) DirectFunctionCall2(timestamp_lt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case INTERVALOID:
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(interval_lt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case TIMETZOID:            
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(timetz_lt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);

        case PG_LSNOID:
            for (i = 1; i < nelements ; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }
                if( (bool) DirectFunctionCall2(pg_lsn_lt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(temp);
        default:
            ereport(ERROR, (errmsg("allowed data type int2, int4, int8, float4, float8, numeric")));                
    }            
}
