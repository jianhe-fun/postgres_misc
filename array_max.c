/*
    /home/jian/Desktop/regress_pgsql/array_max.c
    https://stackoverflow.com/questions/16992339/why-is-postgresql-array-access-so-much-faster-in-c-than-in-pl-pgsql/16996606#16996606

    gcc -I/home/jian/postgres/2023_05_25_beta5421/include/server -fPIC -c /home/jian/Desktop/regress_pgsql/array_max.c
    gcc -shared  -o /home/jian/Desktop/regress_pgsql/array_max.so /home/jian/Desktop/regress_pgsql/array_max.o
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
PG_FUNCTION_INFO_V1(array_max);

Datum 
array_max(PG_FUNCTION_ARGS)
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
    bool        resisnull = true;
    Datum       temp;


    arr =   PG_GETARG_ARRAYTYPE_P(0);

    if (array_contains_nulls(arr))
		ereport(ERROR,
				(errcode(ERRCODE_NULL_VALUE_NOT_ALLOWED),
				 errmsg("array must not contain nulls")));
    if (PG_ARGISNULL(0))                 
        ereport(ERROR, (errmsg("only for non null arrays.")));
    
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
    
    // elog(NOTICE,"base element:%d ",basetype);
    // elog(NOTICE,"number of element:%d in this array",nelements);

    switch (basetype)
    {
        case INT2OID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(int2gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_INT16(DatumGetInt16(temp));
        case INT4OID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(int4gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_INT32(DatumGetInt32(temp));            
        case INT8OID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(int4gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_INT64(DatumGetInt64(temp));
        case FLOAT4OID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(float4gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_FLOAT4(DatumGetFloat4(temp));
        case FLOAT8OID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(float8gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_FLOAT8(DatumGetFloat8(temp));
        case NUMERICOID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(numeric_gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_NUMERIC(DatumGetNumeric(temp));

        case DATEOID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(date_gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_DATEADT(DatumGetDateADT(temp));                                
        case TIMEOID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(time_gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_TIMEADT(DatumGetTimeADT(temp));
        case TIMESTAMPOID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(timestamp_gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_TIMESTAMP(DatumGetTimestamp(temp));
        case TIMESTAMPTZOID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(timestamp_gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_TIMESTAMPTZ(DatumGetTimestampTz(temp));
        case INTERVALOID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(interval_gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_INTERVAL_P(DatumGetIntervalP(temp));                
        case TIMETZOID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(timetz_gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_TIMETZADT_P(DatumGetTimeTzADTP(temp));
        case PG_LSNOID:
            for (i = 0; i < nelements ; i++)
            {
                if (resisnull)
                {
                    temp        = type_oids[i];
                    resisnull   = false;
                } 
                else if( (bool) DirectFunctionCall2(pg_lsn_gt,type_oids[i],temp))
                    temp  = type_oids[i];
            }        
            if (resisnull) 
                PG_RETURN_NULL();
            else
                PG_RETURN_LSN(DatumGetLSN(temp));                                                                                                
        default:
            ereport(ERROR, (errmsg("allowed data type int2, int4, int8, float4, float8, numeric")));                
    }            
}