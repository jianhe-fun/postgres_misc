/*

/home/jian/postgres_misc/parse_container.c
gcc -I/home/jian/postgres/2023_05_25_beta5421/include/server -fPIC -c /home/jian/postgres_misc/parse_container.c
gcc -shared  -o /home/jian/postgres_misc/parse_container.so /home/jian/postgres_misc/parse_container.0

*/
#include "postgres.h"

#include "utils/builtins.h"
#include "funcapi.h"

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(container_1d_parse);

static bool
ContainerCount(const char *str, int *dim, char typdelim, Node *escontext); 

Datum
container_1d_parse(PG_FUNCTION_ARGS)
{
    int 		dim;
    char    	typdelim   = ','; 

	text        *src_txt    = PG_GETARG_TEXT_PP(0);
	char	   *src = text_to_cstring(src_txt);
    Node	   *escontext = fcinfo->context;

    if (ContainerCount(src,&dim,typdelim, escontext))
		PG_RETURN_INT32(dim);
}

/*
 * container_isspace() --- a non-locale-dependent isspace()
 *
 * We used to use isspace() for parsing container values, but that has
 * undesirable results: an container value might be silently interpreted
 * differently depending on the locale setting.  Now we just hard-wire
 * the traditional ASCII definition of isspace().
 */
static bool
container_isspace(char ch)
{
	if (ch == ' ' ||
		ch == '\t' ||
		ch == '\n' ||
		ch == '\r' ||
		ch == '\v' ||
		ch == '\f')
		return true;
	return false;
}

typedef enum
{
	CONTAINER_NO_LEVEL,
	CONTAINER_LEVEL_STARTED,
	CONTAINER_ELEM_STARTED,
	CONTAINER_ELEM_COMPLETED,
	CONTAINER_QUOTED_ELEM_STARTED,
	CONTAINER_QUOTED_ELEM_COMPLETED,
	CONTAINER_LEVEL_COMPLETED,
	CONTAINER_DELIMITED,
	CONTAINER_END
} ContainerParseState;

/*
 * ContainerCount
 *	 Determines the dimensions for an container string.  This includes
 *	 syntax-checking the container structure decoration (braces and delimiters).
 *
 * If we detect an error, fill *escontext with error details and return -1
 * (unless escontext isn't provided, in which case errors will be thrown).
 */
static bool
ContainerCount(const char *str, int *dim, char typdelim, Node *escontext)
{
	int			nest_level = 0,
				i;
	int			ndim = 1,	// one dimension only.
				nelems;		// dimension elements only.
	const char *ptr;
	ContainerParseState parse_state = CONTAINER_NO_LEVEL;

	dim[0] = -1;

	/* Scan string until we reach closing brace */
	ptr = str;
	while (parse_state != CONTAINER_END)
	{
		bool		new_element = false;

		switch (*ptr)
		{
			case '\0':
				/* Signal a premature end of the string */
				ereturn(escontext, -1,
						(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
						 errmsg("malformed conatiner literal: \"%s\"", str),
						 errdetail("Unexpected end of input.")));
			case '\\':
				/*
				 * An escape must be after a level start, after an element
				 * start, or after an element delimiter. In any case we now
				 * must be past an element start.
				 */
				switch (parse_state)
				{
					case CONTAINER_LEVEL_STARTED:
					case CONTAINER_DELIMITED:
						/* start new unquoted element */
						parse_state = CONTAINER_ELEM_STARTED;
						new_element = true;
						break;
					case CONTAINER_ELEM_STARTED:
					case CONTAINER_QUOTED_ELEM_STARTED:
						/* already in element */
						break;
					default:
						ereturn(escontext, -1,
								(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
								 errmsg("malformed container literal: \"%s\"", str),
								 errdetail("Unexpected \"%c\" character.",
										   '\\')));
				}
				/* skip the escaped character */
				if (*(ptr + 1))
					ptr++;
				else
					ereturn(escontext, -1,
							(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
							 errmsg("malformed container literal: \"%s\"", str),
							 errdetail("Unexpected end of input.")));
				break;
			case '"':
				/*
				 * A quote must be after a level start, after a quoted element
				 * start, or after an element delimiter. In any case we now
				 * must be past an element start.
				 */
				switch (parse_state)
				{
					case CONTAINER_LEVEL_STARTED:
					case CONTAINER_DELIMITED:
						parse_state = CONTAINER_QUOTED_ELEM_STARTED;
						new_element = true;
						break;
					case CONTAINER_QUOTED_ELEM_STARTED:
						parse_state = CONTAINER_QUOTED_ELEM_COMPLETED;
						break;
					default:
						ereturn(escontext, -1,
								(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
								 errmsg("malformed container literal: \"%s\"", str),
								 errdetail("Unexpected container element.")));
				}
				break;
			case '{':
                if (parse_state != CONTAINER_QUOTED_ELEM_STARTED)
				{
					/*
					 * A left brace can occur if no nesting has occurred yet,
					 * after a level start
					 */
					if (parse_state != CONTAINER_NO_LEVEL &&
						parse_state != CONTAINER_LEVEL_STARTED &&
						parse_state != CONTAINER_DELIMITED)
						ereturn(escontext, -1,
								(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
								 errmsg("malformed container literal: \"%s\"", str),
								 errdetail("Unexpected \"%c\" character.",
										   '{')));
					parse_state = CONTAINER_LEVEL_STARTED;
					/* Initialize element counting in the new level */
					if (nest_level >= 1)
						ereturn(escontext, -1,
								(errcode(ERRCODE_PROGRAM_LIMIT_EXCEEDED),
								 errmsg("number of container dimensions (%d) exceeds the maximum allowed (%d)",
										nest_level + 1, 1)));
					nelems = 0;
					nest_level++;
				}
				break;
			case '}':
                if (parse_state != CONTAINER_QUOTED_ELEM_STARTED)
				{
					/*
					 * A right brace can occur after an element start, an
					 * element completion, a quoted element completion, or a
					 * level completion.  We also allow it after a level
					 * start, that is an empty sub-container "{}" --- but that
					 * freezes the number of dimensions and all such
					 * sub-container must be at the same level, just like
					 * sub-containers containing elements.
					 */
					switch (parse_state)
					{
						case CONTAINER_ELEM_STARTED:
						case CONTAINER_QUOTED_ELEM_COMPLETED:
						case CONTAINER_LEVEL_COMPLETED:
							/* okay */
							break;
						case CONTAINER_LEVEL_STARTED:
							if (nest_level != ndim)
								ereturn(escontext, -1,
										(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
										 errmsg("malformed container literal: \"%s\"", str),
										 errdetail("Multidimensional container must have sub-containers with matching dimensions.")));
							break;
						default:
							ereturn(escontext, -1,
									(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
									 errmsg("malformed container literal: \"%s\"", str),
									 errdetail("Unexpected \"%c\" character.",
											   '}')));
					}
					parse_state = CONTAINER_LEVEL_COMPLETED;
					/* The parse state check assured we're in a level. */
					Assert(nest_level == 1);
					nest_level--;

					dim[0]	= nelems;
					/* Done if this is the outermost level's '}' */
					if (nest_level == 0)
						parse_state	= CONTAINER_END;
				}
				break;
			default:
                if (parse_state != CONTAINER_QUOTED_ELEM_STARTED)
				{
					if (*ptr == typdelim)
					{
						/*
						 * Delimiters can occur after an element start, a
						 * quoted element completion, or a level completion.
						 */
						if (parse_state != CONTAINER_ELEM_STARTED &&
							parse_state != CONTAINER_QUOTED_ELEM_COMPLETED &&
							parse_state != CONTAINER_LEVEL_COMPLETED)
							ereturn(escontext, -1,
									(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
									 errmsg("malformed container literal: \"%s\"", str),
									 errdetail("Unexpected \"%c\" character.",
											   typdelim)));
                            parse_state = CONTAINER_DELIMITED;
					}
					else if (!container_isspace(*ptr))
					{
						/*
						 * Other non-space characters must be after a level
						 * start, after an element start, or after an element
						 * delimiter. In any case we now must be past an
						 * element start.
						 *
						 * If it's a space character, we can ignore it; it
						 * might be data or not, but it doesn't change the
						 * parsing state.
						 */
						switch (parse_state)
						{
							case CONTAINER_LEVEL_STARTED:
							case CONTAINER_DELIMITED:
								/* start new unquoted element */
								parse_state = CONTAINER_ELEM_STARTED;
								new_element = true;
								break;
							case CONTAINER_ELEM_STARTED:
								/* already in element */
								break;
							default:
								ereturn(escontext, -1,
										(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
										 errmsg("malformed container literal: \"%s\"", str),
										 errdetail("Unexpected container element.")));
						}
					}
				}
				break;
		}

		/* To reduce duplication, all new-element cases go through here. */
		if (new_element)
		{
			/*
			 * Once we have found an element, the number of dimensions can no
			 * longer increase, and subsequent elements must all be at the
			 * same nesting depth.
			 */
			if (nest_level != ndim)
				ereturn(escontext, -1,
						(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
						 errmsg("malformed container literal: \"%s\"", str),
						 errdetail("Multidimensional container must have sub-containers with matching dimensions.")));
			/* Count the new element */
			nelems++;
		}

		ptr++;
	}

	/* only whitespace is allowed after the closing brace */
	while (*ptr)
	{
		if (!container_isspace(*ptr++))
			ereturn(escontext, -1,
					(errcode(ERRCODE_INVALID_TEXT_REPRESENTATION),
					 errmsg("malformed container literal: \"%s\"", str),
					 errdetail("Junk after closing right brace.")));
	}
	return true;
}