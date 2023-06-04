/*
    array_median.c
    
    #### replace to your local include dir, c file, so file, o file.
    gcc -I/home/jian/postgres/2023_05_25_beta5421/include/server -fPIC -c /home/jian/Desktop/regress_pgsql/array_median.c
    gcc -shared  -o /home/jian/Desktop/regress_pgsql/array_median.so /home/jian/Desktop/regress_pgsql/array_median.o
    
    get median of an unsorted array, now only support non-null array.
    base type can be {int2, int4, int8, date, interval, numeric, timestamp, timestamptz}

    * http://ndevilla.free.fr/median/median/src/quickselect.c
    * This Quickselect routine is based on the algorithm described in
    * "Numerical recipes in C", Second Edition,
    * Cambridge University Press, 1992, Section 8.5, ISBN 0-521-43108-5
    *  This code by Nicolas Devillard - 1998. Public domain.
    * 
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
PG_FUNCTION_INFO_V1(array_median);

#define ELEM_SWAP(a,b)     do { register int t=(a);(a)=(b);(b)=t; } while(0)
#define swapDatum(a,b)     do {Datum _tmp; _tmp=a; a=b; b=_tmp;} while(0)

Datum 
array_median(PG_FUNCTION_ARGS)
{
    ArrayType   *arr;
    ArrayType   *arr_copy;
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
    Datum       temp1;
    int		    nullcnt = 0;    /* init value for later doing arithmetic */
    int		    non_nullcnt;

    if (PG_ARGISNULL(0))
        PG_RETURN_NULL();

    arr = PG_GETARG_ARRAYTYPE_P_COPY(0);
     
    //todo use array_remove to alloq array contain null
    if (ARR_HASNULL(arr) && array_contains_nulls(arr))
        elog(ERROR,"%s argument must not contain nulls",__func__);

    // This requirement could probably be lifted pretty easily:
    if (ARR_NDIM(arr) != 1)
        ereport(ERROR, (errmsg("One-dimesional arrays are required")));
    
    //actual data pointer.
    type_oids   = (Datum *) ARR_DATA_PTR(arr);
    basetype    = ARR_ELEMTYPE(arr);        

    get_typlenbyvalalign(basetype, &typlen, &typbyval, &typalign);

    nelements      = ArrayGetNItems(ARR_NDIM(arr), ARR_DIMS(arr));

    // Extract the array contents (as Datum objects).
    deconstruct_array(arr,basetype,typlen,typbyval,typalign,&type_oids,&typnullflag,&nelements);
    
    int low     = 0;
    int high    = nelements - 1;
    int median  = (low + high) / 2;
    int middle,ll, hh;
    temp    = type_oids[0];


    switch (basetype)
    {
        case INT2OID:
            for (;;) 
            {
                if (high <= low)        /* One element only */
                    PG_RETURN_DATUM(type_oids[median]);  

                if (high == low + 1)    /* Two elements only */
                {                  
                    if ( (bool) DirectFunctionCall2(int2gt,type_oids[low],type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                    PG_RETURN_DATUM(type_oids[median]);  
                }

                /* Find median of low, middle and high items; swap into position low */
                middle = (low + high) / 2;
                if ( (bool) DirectFunctionCall2(int2gt,type_oids[middle], type_oids[high]) )
                        swapDatum(type_oids[middle], type_oids[high]);

                if ( (bool) DirectFunctionCall2(int2gt,type_oids[low], type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                if ( (bool) DirectFunctionCall2(int2gt,type_oids[middle], type_oids[low]) )
                        swapDatum(type_oids[middle], type_oids[low]);

                /* Swap low item (now in position middle) into position (low+1) */
                swapDatum(type_oids[middle], type_oids[low+1]);

                /* Nibble from each end towards middle, swapping items when stuck */
                ll = low + 1;
                hh = high;

                for (;;) 
                {
                    do ll++; 
                        while ((bool) DirectFunctionCall2(int2gt,type_oids[low], type_oids[ll])) ;
                    do hh--; 
                        while ((bool) DirectFunctionCall2(int2gt,type_oids[hh], type_oids[low])) ;

                    if (hh < ll)
                    break;

                    swapDatum(type_oids[ll], type_oids[hh]);
                }

                /* Swap middle item (in position low) back into correct position */
                swapDatum(type_oids[low], type_oids[hh]);

                /* Re-set active partition */
                if (hh <= median)
                    low = ll;
                if (hh >= median)
                    high = hh - 1;
            }

        case INT4OID:
            for (;;) 
            {
                if (high <= low)        /* One element only */
                    PG_RETURN_DATUM(type_oids[median]);  

                if (high == low + 1)    /* Two elements only */
                {                  
                    if ( (bool) DirectFunctionCall2(int4gt,type_oids[low],type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                    PG_RETURN_DATUM(type_oids[median]);  
                }

                /* Find median of low, middle and high items; swap into position low */
                middle = (low + high) / 2;
                if ( (bool) DirectFunctionCall2(int4gt,type_oids[middle], type_oids[high]) )
                        swapDatum(type_oids[middle], type_oids[high]);

                if ( (bool) DirectFunctionCall2(int4gt,type_oids[low], type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                if ( (bool) DirectFunctionCall2(int4gt,type_oids[middle], type_oids[low]) )
                        swapDatum(type_oids[middle], type_oids[low]);

                /* Swap low item (now in position middle) into position (low+1) */
                swapDatum(type_oids[middle], type_oids[low+1]);

                /* Nibble from each end towards middle, swapping items when stuck */
                ll = low + 1;
                hh = high;

                for (;;) 
                {
                    do ll++; 
                        while ((bool) DirectFunctionCall2(int4gt,type_oids[low], type_oids[ll])) ;
                    do hh--; 
                        while ((bool) DirectFunctionCall2(int4gt,type_oids[hh], type_oids[low])) ;

                    if (hh < ll)
                    break;

                    swapDatum(type_oids[ll], type_oids[hh]);
                }

                /* Swap middle item (in position low) back into correct position */
                swapDatum(type_oids[low], type_oids[hh]);

                /* Re-set active partition */
                if (hh <= median)
                    low = ll;
                if (hh >= median)
                    high = hh - 1;
            }

        case INT8OID:
            for (;;) 
            {
                if (high <= low)        /* One element only */
                    PG_RETURN_DATUM(type_oids[median]);  

                if (high == low + 1)    /* Two elements only */
                {                  
                    if ( (bool) DirectFunctionCall2(int8gt,type_oids[low],type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                    PG_RETURN_DATUM(type_oids[median]);  
                }

                /* Find median of low, middle and high items; swap into position low */
                middle = (low + high) / 2;
                if ( (bool) DirectFunctionCall2(int8gt,type_oids[middle], type_oids[high]) )
                        swapDatum(type_oids[middle], type_oids[high]);

                if ( (bool) DirectFunctionCall2(int8gt,type_oids[low], type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                if ( (bool) DirectFunctionCall2(int8gt,type_oids[middle], type_oids[low]) )
                        swapDatum(type_oids[middle], type_oids[low]);

                /* Swap low item (now in position middle) into position (low+1) */
                swapDatum(type_oids[middle], type_oids[low+1]);

                /* Nibble from each end towards middle, swapping items when stuck */
                ll = low + 1;
                hh = high;

                for (;;) 
                {
                    do ll++; 
                        while ((bool) DirectFunctionCall2(int8gt,type_oids[low], type_oids[ll])) ;
                    do hh--; 
                        while ((bool) DirectFunctionCall2(int8gt,type_oids[hh], type_oids[low])) ;

                    if (hh < ll)
                    break;

                    swapDatum(type_oids[ll], type_oids[hh]);
                }

                /* Swap middle item (in position low) back into correct position */
                swapDatum(type_oids[low], type_oids[hh]);

                /* Re-set active partition */
                if (hh <= median)
                    low = ll;
                if (hh >= median)
                    high = hh - 1;
            }

        case DATEOID:
            for (;;) 
            {
                if (high <= low)        /* One element only */
                    PG_RETURN_DATUM(type_oids[median]);  

                if (high == low + 1)    /* Two elements only */
                {                  
                    if ( (bool) DirectFunctionCall2(date_gt,type_oids[low],type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                    PG_RETURN_DATUM(type_oids[median]);  
                }

                /* Find median of low, middle and high items; swap into position low */
                middle = (low + high) / 2;
                if ( (bool) DirectFunctionCall2(date_gt,type_oids[middle], type_oids[high]) )
                        swapDatum(type_oids[middle], type_oids[high]);

                if ( (bool) DirectFunctionCall2(date_gt,type_oids[low], type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                if ( (bool) DirectFunctionCall2(date_gt,type_oids[middle], type_oids[low]) )
                        swapDatum(type_oids[middle], type_oids[low]);

                /* Swap low item (now in position middle) into position (low+1) */
                swapDatum(type_oids[middle], type_oids[low+1]);

                /* Nibble from each end towards middle, swapping items when stuck */
                ll = low + 1;
                hh = high;

                for (;;) 
                {
                    do ll++; 
                        while ((bool) DirectFunctionCall2(date_gt,type_oids[low], type_oids[ll])) ;
                    do hh--; 
                        while ((bool) DirectFunctionCall2(date_gt,type_oids[hh], type_oids[low])) ;

                    if (hh < ll)
                    break;

                    swapDatum(type_oids[ll], type_oids[hh]);
                }

                /* Swap middle item (in position low) back into correct position */
                swapDatum(type_oids[low], type_oids[hh]);

                /* Re-set active partition */
                if (hh <= median)
                    low = ll;
                if (hh >= median)
                    high = hh - 1;
            }

        case TIMESTAMPOID:
            for (;;) 
            {
                if (high <= low)        /* One element only */
                    PG_RETURN_DATUM(type_oids[median]);  

                if (high == low + 1)    /* Two elements only */
                {                  
                    if ( (bool) DirectFunctionCall2(timestamp_gt,type_oids[low],type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                    PG_RETURN_DATUM(type_oids[median]);  
                }

                /* Find median of low, middle and high items; swap into position low */
                middle = (low + high) / 2;
                if ( (bool) DirectFunctionCall2(timestamp_gt,type_oids[middle], type_oids[high]) )
                        swapDatum(type_oids[middle], type_oids[high]);

                if ( (bool) DirectFunctionCall2(timestamp_gt,type_oids[low], type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                if ( (bool) DirectFunctionCall2(timestamp_gt,type_oids[middle], type_oids[low]) )
                        swapDatum(type_oids[middle], type_oids[low]);

                /* Swap low item (now in position middle) into position (low+1) */
                swapDatum(type_oids[middle], type_oids[low+1]);

                /* Nibble from each end towards middle, swapping items when stuck */
                ll = low + 1;
                hh = high;

                for (;;) 
                {
                    do ll++; 
                        while ((bool) DirectFunctionCall2(timestamp_gt,type_oids[low], type_oids[ll])) ;
                    do hh--; 
                        while ((bool) DirectFunctionCall2(timestamp_gt,type_oids[hh], type_oids[low])) ;

                    if (hh < ll)
                    break;

                    swapDatum(type_oids[ll], type_oids[hh]);
                }

                /* Swap middle item (in position low) back into correct position */
                swapDatum(type_oids[low], type_oids[hh]);

                /* Re-set active partition */
                if (hh <= median)
                    low = ll;
                if (hh >= median)
                    high = hh - 1;
            }

        case TIMESTAMPTZOID:
            for (;;) 
            {
                if (high <= low)        /* One element only */
                    PG_RETURN_DATUM(type_oids[median]);  

                if (high == low + 1)    /* Two elements only */
                {                  
                    if ( (bool) DirectFunctionCall2(timestamptz_gt_timestamp,type_oids[low],type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                    PG_RETURN_DATUM(type_oids[median]);  
                }

                /* Find median of low, middle and high items; swap into position low */
                middle = (low + high) / 2;
                if ( (bool) DirectFunctionCall2(timestamptz_gt_timestamp,type_oids[middle], type_oids[high]) )
                        swapDatum(type_oids[middle], type_oids[high]);

                if ( (bool) DirectFunctionCall2(timestamptz_gt_timestamp,type_oids[low], type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                if ( (bool) DirectFunctionCall2(timestamptz_gt_timestamp,type_oids[middle], type_oids[low]) )
                        swapDatum(type_oids[middle], type_oids[low]);

                /* Swap low item (now in position middle) into position (low+1) */
                swapDatum(type_oids[middle], type_oids[low+1]);

                /* Nibble from each end towards middle, swapping items when stuck */
                ll = low + 1;
                hh = high;

                for (;;) 
                {
                    do ll++; 
                        while ((bool) DirectFunctionCall2(timestamptz_gt_timestamp,type_oids[low], type_oids[ll])) ;
                    do hh--; 
                        while ((bool) DirectFunctionCall2(timestamptz_gt_timestamp,type_oids[hh], type_oids[low])) ;

                    if (hh < ll)
                    break;

                    swapDatum(type_oids[ll], type_oids[hh]);
                }

                /* Swap middle item (in position low) back into correct position */
                swapDatum(type_oids[low], type_oids[hh]);

                /* Re-set active partition */
                if (hh <= median)
                    low = ll;
                if (hh >= median)
                    high = hh - 1;
            }

        case INTERVALOID:
            for (;;) 
            {
                if (high <= low)        /* One element only */
                    PG_RETURN_DATUM(type_oids[median]);  

                if (high == low + 1)    /* Two elements only */
                {                  
                    if ( (bool) DirectFunctionCall2(interval_gt,type_oids[low],type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                    PG_RETURN_DATUM(type_oids[median]);  
                }

                /* Find median of low, middle and high items; swap into position low */
                middle = (low + high) / 2;
                if ( (bool) DirectFunctionCall2(interval_gt,type_oids[middle], type_oids[high]) )
                        swapDatum(type_oids[middle], type_oids[high]);

                if ( (bool) DirectFunctionCall2(interval_gt,type_oids[low], type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                if ( (bool) DirectFunctionCall2(interval_gt,type_oids[middle], type_oids[low]) )
                        swapDatum(type_oids[middle], type_oids[low]);

                /* Swap low item (now in position middle) into position (low+1) */
                swapDatum(type_oids[middle], type_oids[low+1]);

                /* Nibble from each end towards middle, swapping items when stuck */
                ll = low + 1;
                hh = high;

                for (;;) 
                {
                    do ll++; 
                        while ((bool) DirectFunctionCall2(interval_gt,type_oids[low], type_oids[ll])) ;
                    do hh--; 
                        while ((bool) DirectFunctionCall2(interval_gt,type_oids[hh], type_oids[low])) ;

                    if (hh < ll)
                    break;

                    swapDatum(type_oids[ll], type_oids[hh]);
                }

                /* Swap middle item (in position low) back into correct position */
                swapDatum(type_oids[low], type_oids[hh]);

                /* Re-set active partition */
                if (hh <= median)
                    low = ll;
                if (hh >= median)
                    high = hh - 1;
            }

        case NUMERICOID:
            for (;;) 
            {
                if (high <= low)        /* One element only */
                    PG_RETURN_DATUM(type_oids[median]);  

                if (high == low + 1)    /* Two elements only */
                {                  
                    if ( (bool) DirectFunctionCall2(numeric_gt,type_oids[low],type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                    PG_RETURN_DATUM(type_oids[median]);  
                }

                /* Find median of low, middle and high items; swap into position low */
                middle = (low + high) / 2;
                if ( (bool) DirectFunctionCall2(numeric_gt,type_oids[middle], type_oids[high]) )
                        swapDatum(type_oids[middle], type_oids[high]);

                if ( (bool) DirectFunctionCall2(numeric_gt,type_oids[low], type_oids[high]) )
                        swapDatum(type_oids[low], type_oids[high]);

                if ( (bool) DirectFunctionCall2(numeric_gt,type_oids[middle], type_oids[low]) )
                        swapDatum(type_oids[middle], type_oids[low]);

                /* Swap low item (now in position middle) into position (low+1) */
                swapDatum(type_oids[middle], type_oids[low+1]);

                /* Nibble from each end towards middle, swapping items when stuck */
                ll = low + 1;
                hh = high;

                for (;;) 
                {
                    do ll++; 
                        while ((bool) DirectFunctionCall2(numeric_gt,type_oids[low], type_oids[ll])) ;
                    do hh--; 
                        while ((bool) DirectFunctionCall2(numeric_gt,type_oids[hh], type_oids[low])) ;

                    if (hh < ll)
                    break;

                    swapDatum(type_oids[ll], type_oids[hh]);
                }

                /* Swap middle item (in position low) back into correct position */
                swapDatum(type_oids[low], type_oids[hh]);

                /* Re-set active partition */
                if (hh <= median)
                    low = ll;
                if (hh >= median)
                    high = hh - 1;
            }
        default:
            ereport(ERROR, (errmsg("allowed data type int2, int4, int8, float4, float8, numeric")));                 
    }
}