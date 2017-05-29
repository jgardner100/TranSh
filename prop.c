#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "mysh.h"

LISTHEAD *head = NULL;

PUBLIC void init_prop( void)
{
	head = list_start();
}

PUBLIC void close_prop( void)
{
	list_destroy( head);
	free( head);
}

PUBLIC void add_prop( char *prop_name, char *prop_value)
{
	list_insert( head, prop_name, prop_value, NULL, 0);
}

PUBLIC char *get_prop( char *name)
{
	char *ret;
	LISTNODE *ptr;

	ptr = list_get( head, name);
	if( ptr == NULL)
		ret = "";
	else
		ret = ptr->value;

	return ret;
}

PUBLIC void summary_prop( void)
{
	printf( "Properties\n");
	dump_list( head);
}
