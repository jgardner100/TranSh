#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#include "TranSh.h"

/*
 * Stuff that goes here is to affect what the lex analyzer will
 * process (i.e. #include processing etc)
 */

PUBLIC struct node_struct *prog = NULL;
PUBLIC FILE *yyin;
PUBLIC FILE *yyout;
PRIVATE int to_screen = FALSE;
PRIVATE int do_debug = FALSE;
PUBLIC int do_summary = FALSE;
extern char *g_output_type;

PUBLIC
PUBLIC void debug( int linenum, char *fmt, char *msg)
{
	if( do_debug)
	{
		printf("%d: ",linenum);
		if( fmt == NULL)
			printf( "DEBUG: %s\n", msg);
		else
			printf( fmt, msg);
	}
}

PUBLIC FILE *mopen( char *fname, char *mode)
{
	FILE *mfile;

	mfile = fopen( fname, mode);
	if( mfile == NULL)
	{
		perror( "fopen");
		fprintf( stderr, "** Can't open %s\n", fname);
		exit(1);
	}

	return mfile;
}

PRIVATE char *remove_ext( char *name)
{
	static char str[512];
	char *ret;
	int i;

	strcpy( str, name);
	for( i = 0; str[i] != '.' && str[i] != '\0'; i++)
		;

	str[i] = '\0';

	ret = strdup( str);

	return ret;
}

PRIVATE void process( char *type)
{
	int result;

	result = yyparse();

	if( result != 0)
	{
		fprintf( stderr, "Failed to parse\n");
		exit(1);
	}

	if( prog == NULL)
	{
		fprintf( stderr, "Missing program\n");
		exit(1);
	}
	
	start_tran( type, prog);
	do_free( prog);
}

PUBLIC int main( int argc, char *argv[])
{
	int c;
	char *type_str = "default", *name, *in_name;
	char *ofname_str = NULL;
	char out_name[128];
	BUFFER *buf;

	init_tracker();
	init_prop();

	while( (c = getopt( argc, argv, "adho:st:v")) != -1) {
		int this_option_optind = optind ? optind : 1;
		switch( c) {
		case 'a':
			to_screen = TRUE;
			break;
		case 'd':
			do_debug = TRUE;
			break;
		case 'h':
			break;
		case 'o':
			ofname_str = optarg;
			break;
		case 's':
			do_summary = TRUE;
			break;
		case 't':
			type_str = optarg;
			break;
		case 'v':
			printf( "Version %s\n", VERSION);
			exit(0);
			break;
		default:
			printf( "?? getopt returned code 0%o ??\n", c);
			exit(1);
		}
	}
	if( optind < argc)
	{
		while (optind < argc)
		{
			in_name = strdup( argv[optind]);

			name = strdup( remove_ext( argv[optind]));
			debug( 0, "open %s\n", in_name);
			debug( 0, "name %s.sh\n", name);
			add_prop( "name", name);

			if( ofname_str == NULL)
				sprintf( out_name, "%s.sh", name);
			else
				sprintf( out_name, "%s", ofname_str);

			debug( 0, "call open_file with %s\n", in_name);
			buf = open_file( in_name);
			if( buf != NULL)
			{
				init_lex( 0, in_name);
				while( preprocess_file(buf) == TRUE)
					;
				process_file(buf);

				if( ! to_screen)
					yyout = mopen(out_name, "w+");

				process( type_str);

				if( ! to_screen)
					fclose( yyout);
				close_file(buf);
			}
			else
				fprintf( stderr, "- Can't open %s\n", argv[optind]);
			optind++;
			free(name);
		}
	}
	else
	{
			debug( 0, "no options given\n", NULL);
			process( type_str);
	}

/*
	if( do_summary)
	{
		tracker_summary();
		summary_prop();
	}
*/

	close_tracker();
	close_prop();

	exit(0);
}
