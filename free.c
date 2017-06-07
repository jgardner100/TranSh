#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "TranSh.h"

PUBLIC void do_free( struct node_struct *prog)
{

	struct node_struct *ptr;

	for( ptr = prog; ptr != NULL; ptr = ptr->next)
	{
		free( ptr);
	}
}
