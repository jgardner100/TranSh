#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "TranSh.h"

PRIVATE int g_linecnt=0;

PUBLIC void lnx_dump_comment( NODE *comment)
{
        if( g_linecnt == 0)
                INDENTB(printf("#!/bin/bash\n");)
        else
                INDENTB(printf("%s\n", comment->name);)
        g_linecnt++;
}

PUBLIC void lnx_do_tran( struct node_struct *prog)
{

	struct node_struct *ptr;
	int x=0;

	level = 0;
	for( ptr = prog; ptr != NULL; ptr = ptr->next)
	{
		if( ptr->type == T_PROC )
		{
			printf( "%s() {\n", ptr->name);

			JUMPUP
			dump_args( NULL, ptr->args);
			dump_code_chain( NULL, ptr->code);
			JUMPBK

			printf( "}\n");
		}
		else
			dump_code( NULL, ptr);
		x++;
	}
}
