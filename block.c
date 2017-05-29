#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "mysh.h"

struct block_struct {
	char *name;
	char *lines[16];
} block[] = {
	 { "do_init",
		{ 
		  "function cleanup {\n"
		  ,"	echo Stopping\n"
		  ,"	rm -f $TMPENV\n"
		  ,"	echo Done\n"
		  ,"	exit 0\n"
		  ,"}\n"
		  ,"trap cleanup SIGTERM SIGINT\n"
		  ,"trap \"\" SIGHUP\n"
		  ,"TMPDIR=\"$HOME/refresh/tmp\"\n"
		  ,"TMPENV=\"$TMPDIR/%s-file.$$\"\n\n"
		  ,". $HOME/refresh/bin/funcs.sh\n"
		  ,NULL
		}
	}
	,{ "do_finish",
		{
		  "rm -f $TMPENV\n"
		  ,"\n"
		  ,"exit 0\n"
		  ,NULL
		}
	}
};
typedef struct block_struct BLOCK;

PUBLIC void dump_block( NODE *code)
{
	int i, x, found;

	debug( 0, "block code = %s\n", code->name);
	found = 0;
	for( i = 0; i < LEN(block,BLOCK); i++)
		if( strcmp( block[i].name, code->name) == 0)
		{
			for( x = 0; block[i].lines[x] != NULL; x++)
				fprintf( yyout, block[i].lines[x], get_prop( "name"));
			found = 1;
		}

	if( ! found)
		printf( "Can't find block %s\n", code->name);
}
