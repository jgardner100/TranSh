#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "TranSh.h"

PRIVATE void sol_dump_code( NODE *code);
PRIVATE int g_linecnt=0;

PUBLIC void sol_dump_comment( NODE *comment)
{
        if( g_linecnt == 0)
                INDENTB(printf("#!/bin/ksh\n");)
        else
                INDENTB(printf("%s\n", comment->name);)
        g_linecnt++;
}

PUBLIC void sol_dump_statem( NODE *code)
{
        NODE *args;

	if( strcmp( code->name, "echo") == 0)
        	INDENTB(printf("echo ");)
	else if( strcmp( code->name, "awk") == 0)
        	INDENTB(printf("nawk ");)
	else
        	INDENTB(printf("%s ", code->name);)

        for( args=code->args; args != NULL; args = args->next)
                printf("%s ", args->name);

        printf("\n");
}

PUBLIC void sol_do_tran( NODE *prog)
{

	NODE *ptr;
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
