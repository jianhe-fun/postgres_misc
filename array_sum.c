
/*
    /home/jian/Desktop/regress_pgsql/array_sum.c
    https://stackoverflow.com/questions/16992339/why-is-postgresql-array-access-so-much-faster-in-c-than-in-pl-pgsql/16996606#16996606

    gcc -I/home/jian/postgres/2023_05_25_beta5421/include/server -fPIC -c /home/jian/Desktop/regress_pgsql/array_sum.c
    gcc -shared  -o /home/jian/Desktop/regress_pgsql/array_sum.so /home/jian/Desktop/regress_pgsql/array_sum.o
*/

#include "postgres.h"

#include "utils/builtins.h"
#include "utils/array.h"
#include "utils/numeric.h"
#include "utils/timestamp.h"
#include "funcapi.h"
#include "utils/lsyscache.h"
#include "utils/fmgrprotos.h"

PG_MODULE_MAGIC;
PG_FUNCTION_INFO_V1(array_sum);

Datum 
array_sum(PG_FUNCTION_ARGS)
{
    ArrayType   *arr;
    Datum       *type_oids;
    Oid         basetype;
    int         nelements;
    int16       typlen;         /* needed info about element datatype */
    bool        typbyval;       /* needed info about element datatype */
    char        typalign;       /* needed info about element datatype */
    bool        *typnullflag;   /* null bit map */
    int         i;
    int		    ndim;
    int		    nullcnt = 0;    /* init value for later doing arithmetic */
    int		    non_nullcnt;
    bool        resisnull = true;
    Datum       sumd;
                
    if (PG_ARGISNULL(0))                 
        ereport(ERROR, (errmsg("only for non null arrays.")));
    
    arr =   PG_GETARG_ARRAYTYPE_P(0);

    //This requirement could probably be lifted pretty easily:
    ndim = ARR_NDIM(arr);
    if (ndim == 0)
	        ereport(ERROR, (errmsg("empty array not allowed")));
    else if (ndim > 1)
	        ereport(ERROR, (errmsg("One-dimesional arrays are required")));


    //actual data pointer.
    type_oids   = (Datum *) ARR_DATA_PTR(arr);
    /* get array container base type */
    basetype    = ARR_ELEMTYPE(arr);            

    if (basetype != INT2OID && basetype != INT4OID &&         
        basetype != INT8OID && basetype != FLOAT4OID && 
        basetype != FLOAT8OID && basetype != NUMERICOID &&
        basetype != INTERVALOID)
        ereport(ERROR,
                (errmsg("allowed data type int2, int4,int8,"
                        "float4,float8,numeric, interval")));

    get_typlenbyvalalign(basetype, &typlen, &typbyval, &typalign);
    nelements      = ArrayGetNItems(ARR_NDIM(arr), ARR_DIMS(arr));

    if (nelements == 0) 
        PG_RETURN_NULL();

    deconstruct_array(arr,basetype,typlen,typbyval
                            ,typalign,&type_oids,&typnullflag,&nelements);

    switch (basetype)
    {
        case INT8OID:
            /* for properly datatype datum value initialize */
            sumd = DirectFunctionCall1(int8_numeric, 0);
            for (i = 0; i < nelements; i++)
            {
                if (typnullflag[i])
                {
                    nullcnt++;
                    // elog(NOTICE,"nullcnt:%d", nullcnt);
                    continue;
                }
                sumd = DirectFunctionCall2(
                        numeric_add
                        ,DirectFunctionCall1(int8_numeric, type_oids[i]), sumd);
            }

            non_nullcnt = nelements - nullcnt;        
            // elog(NOTICE," nelements:%d nullcnt:%d ,non_nullcnt:%d",nelements,nullcnt,non_nullcnt);
            if (non_nullcnt == 0)
                PG_RETURN_NULL();
            else
                 PG_RETURN_DATUM(sumd);
     
        case INT2OID:
            /* for properly datatype datum value initialize */
            sumd = Int64GetDatum(0);

            for (i = 0; i < nelements ; i++)
            {
                if(typnullflag[i])
                {
                    nullcnt++;
                    // elog(NOTICE,"nullcnt:%d", nullcnt);
                    continue;
                }    
                sumd  = DirectFunctionCall2(int8pl,Int64GetDatum(type_oids[i]),sumd);
            } 
            non_nullcnt = nelements - nullcnt;     
            if (non_nullcnt == 0)                 
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(sumd);

        case INT4OID:
            /* for properly datatype datum value initialize */
            sumd = Int64GetDatum(0);             

            for (i = 0; i < nelements ; i++)
            {
                if(typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }       
                sumd  = DirectFunctionCall2(int8pl,Int64GetDatum(type_oids[i]),sumd);
            }   

            non_nullcnt = nelements - nullcnt;        
            if (non_nullcnt == 0)
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(sumd);

        case FLOAT4OID:
            /* for properly datatype datum value initialize */
            sumd = Float4GetDatum(0.0f);             
            for (i = 0; i < nelements ; i++)
            {
                if(typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }    
                sumd  = DirectFunctionCall2(float4pl,type_oids[i],sumd);
            } 
            non_nullcnt = nelements - nullcnt;   

            if (non_nullcnt == 0)                   
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(sumd);

        case FLOAT8OID:
            /* for properly datatype datum value initialize */
            sumd = Float8GetDatum(0.0f);             

            for (i = 0; i < nelements ; i++)
            {
                if(typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }    
                sumd  = DirectFunctionCall2(float8pl,type_oids[i],sumd);
            }      

            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)  
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(sumd);

        case INTERVALOID:           
            sumd    =   DirectFunctionCall6(make_interval,0,0,0,0,0,0);

            for (i = 0; i < nelements ; i++)
            {
                if(typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }   
                sumd  =  DirectFunctionCall2(interval_pl,type_oids[i],sumd);
            }     
            
            non_nullcnt = nelements - nullcnt;      
            if (non_nullcnt == 0)            
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(sumd);

        case NUMERICOID:
            /* for properly datatype datum value initialize */
            sumd = DirectFunctionCall1(int8_numeric,0);

            for (i = 0; i < nelements ; i++)
            {
                if(typnullflag[i])
                {
                    nullcnt++;
                    continue;
                }   
                sumd    = DirectFunctionCall2(numeric_add,type_oids[i],sumd);
            }       
            
            non_nullcnt = nelements - nullcnt;   
            if (non_nullcnt == 0)        
                PG_RETURN_NULL();
            else
                PG_RETURN_DATUM(sumd);
        default:
            ereport(ERROR, (errmsg("allowed data type int2, int4, int8, float4, float8, numeric")));    
    }    
}
