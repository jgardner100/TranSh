#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "TranSh.h"

typedef struct func_type_struct {
	char *name;
	char *type_str;
	int type;
} FUNCTYPE;

PRIVATE LISTHEAD *func_chain = NULL;

PUBLIC void init_tracker(void)
{
	func_chain = list_start();
}

PUBLIC void close_tracker(void)
{
	list_destroy( func_chain);
}

PUBLIC void tracker_summary(LISTHEAD *global_vars)
{
	printf("\n");

	if( func_chain != NULL)
	{
		printf("functions:\n");
		dump_list( func_chain);
	}

	if( global_vars != NULL)
	{
		printf("Global Vars:\n");
		dump_list( global_vars);
	}
}

/*
 * Track function & variables types
 */

PUBLIC void add_func( char *func_name)
{
	if( func_chain != NULL && func_name != NULL)
		list_insert( func_chain, func_name, NULL, NULL, 0);

	return;
}

/*
 * Save the func name and arguements types for static checking.
 */
PUBLIC void add_func_args( char *func_name, NODE *args)
{
	NODE *ptr;
	int count, i;
	FUNCTYPE *types;

	for( ptr = args, count = 0; ptr != NULL; ptr = ptr->next)
		count++;

	types = malloc( sizeof( FUNCTYPE) * count);
	if( types == NULL)
	{
		fprintf( stderr, "%s %d: Out of mem in add_func_args()\n", args->file_name, args->lineno);
		exit(1);
	}

	for( ptr = args, i = 0; ptr != NULL; ptr = ptr->next)
	{
		types[i].name = ptr->name;
		types[i].type_str = ptr->var_type->name;
		types[i].type = ptr->var_type->type;
		i++;
	}

	list_insert( func_chain, func_name, NULL, (void *)types,count);

	return;
}

/*
 * Get the func details based on the name.
 */
PUBLIC LISTNODE *find_func( char *func_name)
{
	LISTNODE *ptr;

	for( ptr = func_chain->start; ptr != NULL; ptr = ptr->next)
		if( strcmp( ptr->name, func_name) == 0)
			return ptr;

	return NULL;
}

/*
 * Get the func details based on the name.
 */
PUBLIC char *find_func_name( char *func_name)
{
	LISTNODE *ptr;

	for( ptr = func_chain->start; ptr != NULL; ptr = ptr->next)
		if( strcmp( ptr->name, func_name) == 0)
			return ptr->name;

	return NULL;
}
PRIVATE int compare_types( int typea, int typeb)
{
	if( typea == typeb)
		return TRUE;
	else if( typea == T_CONST && typeb == T_STR)
		return TRUE;
	else if( typeb == T_CONST && typea == T_STR)
		return TRUE;

	return FALSE;
}

PUBLIC void check_func_args( char *fname, NODE *args)
{
	LISTNODE *arg_types;
	NODE *ptr, *list;
	FUNCTYPE *types;
	int count, i;

	arg_types = find_func( fname);
	if( arg_types == NULL)
	{
		fprintf( stderr, "%s %d: Can't find function %s\n", args->file_name, args->lineno, fname);
		return;
	}

	types = (FUNCTYPE *)arg_types->content;
	count = 0;
	for ( ptr = args; ptr != NULL; ptr = ptr->next)
	{
		if ( count >= arg_types->content_count)
			fprintf( stderr, "%s %d: [%s] too many args\n"
					,args->file_name
					,args->lineno
					,fname
			);
		else 
		{
			if ( !compare_types( ptr->type, types[count].type) )
			{
				printf( "%s %d: %s(",
					ptr->file_name,
					ptr->lineno,
					fname
				);
				for ( list = args, i=0; list != NULL && i < arg_types->content_count; list = list->next)
				printf( "%s = %s ",
					types[i++].name,
					list->name
				);
				printf( ") param %s ", 
					types[count].name
				);
				printf( "should be %s\n", types[count].type_str);
			}
		}
		count++;
	}

	if ( count < arg_types->content_count)
		fprintf( stderr, "%s %d: %s too few args (%d)\n"
				,args->file_name
				,args->lineno
				,fname
				,count
		);
}

PUBLIC void add_var( LISTHEAD *chain, char *var_name, int type)
{
	VARTYPE *var_info;

	var_info = malloc( sizeof( VARTYPE));
	var_info->type = type;
	var_info->name = strdup(var_name);;

	if( type > 200)
	{
		printf( "Got %s type %d\n", var_name, type);
		exit(1);
	}

	list_insert( chain, var_name, NULL, (void *)var_info, 0);
}

PUBLIC VARTYPE *find_var( LISTHEAD *chain, char *var_name)
{
	LISTNODE *ptr;

	debug( 0, "hunt for var %s\n", var_name); 
	if( chain != NULL)
		for( ptr = chain->start; ptr != NULL; ptr = ptr->next)
		{
			debug( 0, "probe var %s\n", ptr->name); 
			if( strcmp( ptr->name, var_name) == 0)
				return ptr->content;
		}

	return NULL;
}

PUBLIC LISTHEAD *start_scope()
{
	LISTHEAD *chain;

	chain = list_start();

	return chain;
}

PUBLIC LISTHEAD *end_scope( LISTHEAD *chain)
{
	list_destroy( chain);
	free( chain);

	return NULL;
}
