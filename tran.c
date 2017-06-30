#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "TranSh.h"

extern void lnx_dump_comment( NODE *comment);
extern void lnx_do_tran( NODE *prog);
extern void sol_dump_comment( NODE *comment);
extern void sol_dump_statem( NODE *code);

extern FILE *yyout;

PRIVATE LISTHEAD *global_var = NULL;

PRIVATE struct probe_struct {
        char *type_name;
        void (*do_tran)( NODE *comment);
        void (*dump_comment)( NODE *comment);
        void (*dump_statem)( NODE *code);
} probes[] = {
	{ "linux", lnx_do_tran, lnx_dump_comment, NULL}
	,{ "solaris", NULL, sol_dump_comment, NULL}
};

PRIVATE int g_linecnt=0;
PRIVATE char *g_output_type="default";

PUBLIC int level = 0;
PUBLIC void tab_level( int tab_level)
{
	int i;

	for( i = 0; i < tab_level; i++)
		fprintf( yyout, "\t");
}

PUBLIC void dump_comment( NODE *comment)
{
	int i;

	DOPROBE( dump_comment, comment)

	if( g_linecnt == 0 && strncmp( comment->name, "#!", 2) == 0)
	{
		fprintf( yyout, "#!/bin/bash\n");
		g_linecnt++;
	}
	else if( strncmp( comment->name, "#line", 5) == 0)
	{
		debug( comment->lineno, "got line directive %s\n", strip_cr(comment->name));
		// fprintf( yyout, "%s\n", comment->name);
	}
	else
	{
		INDENTB( fprintf( yyout, "%s\n", strip_cr(comment->name));)
		g_linecnt++;
	}
}

PUBLIC char *type_to_name( int type)
{
	char *type_str;

	switch( type) {
		case T_INT:
			type_str = "int";
			break;
		case T_CONST:
			type_str = "const";
			break;
		case T_STR:
			type_str = "str";
			break;
		default:
			type_str = "unknown";
	}

	return type_str;
}

PUBLIC char *type_to_str( NODE *var_type)
{
	char *type_str;

	switch( var_type->type) {
		case T_INT:
			type_str = " -i ";
			break;
		case T_CONST:
			type_str = " -r ";
			break;
		case T_STR:
			type_str = " ";
			break;
		default:
			type_str = "unknown";
	}

	return type_str;
}

PUBLIC void dump_args( LISTHEAD *localvars, struct node_struct *arg)
{
	NODE *ptr, *type;
	char *type_str;
	int i=1;

	for( ptr=arg; ptr != NULL; ptr = ptr->next)
	{
		type = ptr->var_type;
		if( type->type == T_ALL)
		{
			if( i > 1)
				INDENTB( fprintf( yyout, "shift\n");)
			INDENTB( fprintf( yyout, "typeset %s=\"$*\"\n", ptr->name);)
		}
		else
		{
			type_str = type_to_str( type);

			INDENTB( fprintf( yyout, "typeset%s%s=\"$%d\"\n", type_str, ptr->name, i++);)
			add_var( localvars, ptr->name, type->type);
		}
	}
	fprintf( yyout, "\n");
}

PUBLIC void dump_code_chain( LISTHEAD *localvars, struct node_struct *code)
{
	struct node_struct *ptr, *args;

	for( ptr=code; ptr != NULL; ptr = ptr->next)
		dump_code( localvars, ptr);
}

/*
 * Strip out the "<<" & ">" marks from redir string
 */
PUBLIC char *strip_redir( char *line)
{
	static char buffer[512];
        int i, len;

	buffer[0] = '\0';
	strcpy( buffer, &line[2]);
        len = strlen( buffer);
	buffer[len-2] = '\0';

        return buffer;
}

/*
 * Strip out an carridge returns
 */
PUBLIC char *strip_cr( char *line)
{
        int i, len;

        len = strlen( line);
        for( i = 0; i <len; i++)
                if( line[i] == '\n')
                        line[i] = '\0';

        return line;
}

/*
 * Remove the quote marks around a string
 */
PUBLIC char *strip_str( char *str)
{
        static char nstr[512];

        strcpy( nstr, str);

        nstr[strlen(nstr) - 1] = '\0';

        return &nstr[1];
}

PUBLIC void dump_getopt( char *options)
{
	char *opt_vals[128], *opt_type[128], *opt_vars[128];
	char *val_tok, *val_type, *var_tok;
	char opt_str[512];
	int count = 0, i;

	options = strip_str( options);

	opt_str[0] = '\0';
	val_tok = strtok( options, ",");
	while( val_tok != NULL)
	{
		var_tok = strtok( NULL, ",");

		opt_vals[count] = val_tok;
		opt_type[count] = val_type;
		opt_vars[count] = var_tok;

		strcat( opt_str, opt_vals[count]);

		count++;

		val_tok = strtok( NULL, ",");
	}

	fprintf( yyout, "set -- `getopt %s $*`;\n", opt_str);
	fprintf( yyout, "if [ \"$?\" != 0 ]\n");
	fprintf( yyout, "then\n");
	fprintf( yyout, "        echo $USAGE\n");
	fprintf( yyout, "        exit 2\n");
	fprintf( yyout, "fi\n");
	fprintf( yyout, "for i in $*\n");
	fprintf( yyout, "do\n");
	fprintf( yyout, "        case $i in\n");

	for( i = 0; i < count; i++)
	{
		if( opt_vals[i][1] == ':')
			fprintf( yyout, "        -%c)           %s=$2; shift 2;;\n",
				opt_vals[i][0],
				opt_vars[i]);
		else
			fprintf( yyout, "        -%s)           %s=$i; shift;;\n",
				opt_vals[i],
				opt_vars[i]);
	}

	fprintf( yyout, "        --)           shift; break;;\n");
	fprintf( yyout, "        esac\n");
	fprintf( yyout, "done\n");

}

PUBLIC void dump_elif( LISTHEAD *localvars, struct node_struct *code)
{
	if( code->test_str->type == T_STRING)
	{
		INDENT fprintf( yyout, "elif %s; then\n", code->test_str->name);
	}
	else
	{
		INDENT fprintf( yyout, "elif [ %s ]; then\n", code->test_str->name);
	}
	JUMPUP
	dump_code_chain( localvars, code->code);
	JUMPBK

	if( code->next != NULL)
		dump_elif( localvars, code->next);
}

PUBLIC void dump_func_args( char *fname, NODE *args)
{
	if( args != NULL)
	{
		check_func_args( fname, args);
		fprintf( yyout, "%s", args->name);
		for(args=args->next; args != NULL; args = args->next)
			fprintf( yyout, " %s", args->name);
	}
}

PUBLIC void dump_options_values( NODE *opt_list)
{
	fprintf( yyout, "%s", opt_list->name);
	if( opt_list->next != NULL)
	{
		fprintf( yyout, "|");
		dump_options_values( opt_list->next);
	}
}

PUBLIC void dump_options( LISTHEAD *localvars, NODE *code)
{
	tab_level( level);
	if( code->opt_list != NULL)
		dump_options_values( code->opt_list);
	fprintf( yyout, ")\n");

	JUMPUP
	if( code->code != NULL)
		dump_code_chain( localvars, code->code);
	INDENT fprintf( yyout, ";;\n");
	JUMPBK

	if( code->next != NULL)
		dump_options( localvars, code->next);
}

PUBLIC void dump_statem( NODE *code)
{
	NODE *args;
	int i;

	DOPROBE( dump_statem, code)

	INDENT fprintf( yyout, "%s", code->name);

	for( args=code->args; args != NULL; args = args->next)
	{
		if( args->type == T_REDIR)
			fprintf( yyout, " <<EOF%s\nEOF\n", strip_redir( args->name));
		else
			fprintf( yyout, " %s", args->name);
	}
}

PRIVATE void add_var_list( LISTHEAD *localvars, LISTHEAD *global_var, char *name, int type)
{
	if( localvars == NULL)
		add_var( global_var, name, type);
	else
		add_var( localvars, name, type);
}

PRIVATE char *type_to_fullstring( int type)
{
	char *ret_str;

	switch(type)
	{
		case T_INT:
			ret_str = "int";
			break;
		case T_STR:
			ret_str = "str";
			break;
		case T_CONST:
			ret_str = "const";
			break;
		default:
			ret_str = "unknown";
	}

	return ret_str;
}

PUBLIC void dump_decl( LISTHEAD *localvars, NODE *code)
{
	NODE *args;
	char *typeset;

	typeset = type_to_str( code->var_type);
		
	if( code->var_list == NULL)
	{
		fprintf( stderr, "eek, var list is empty!!\n");
		exit(1);
	}

	if( localvars != NULL) /* local proc */
	{
		for( args = code->var_list; args != NULL; args = args->next)
		{
			if( args->var_value != NULL)
			{
				if( code->var_type->type != args->var_value->type)
					printf( "%s(%s) assigned wrong type %s\n", args->name, type_to_fullstring(code->var_type->type), type_to_fullstring(args->var_value->type));
			}
			INDENTB( fprintf( yyout, "typeset%s", typeset);)
			debug( 0, "should add local %s\n", args->name);
			add_var_list(localvars,global_var,args->name, code->var_type->type);
			if( args->var_value != NULL)
				fprintf( yyout, "%s=%s ",
					args->name,
					args->var_value->name
				);
			else
				fprintf( yyout, "%s\n", args->name);
		}
		fprintf( yyout, "\n");
	}
	else /* in global zone */
	{
		for( args = code->var_list; args != NULL; args = args->next)
		{
			if( args->var_value != NULL)
			{
				if( code->var_type->type != args->var_value->type)
					printf( "%s(%s) assigned wrong type %s\n", args->name, type_to_fullstring(code->var_type->type), type_to_fullstring(args->var_value->type));
			}
			debug( 0, "should add local %s\n", args->name);
			add_var_list(localvars,global_var,args->name,code->var_type->type);
			if( args->var_value != NULL)
				fprintf( yyout, "%s=%s\n",
					args->name,
					args->var_value->name
				);
		}
	}
}

PRIVATE char *translate_expr( char * expr)
{
	char *ret_str;

	if( strcmp( expr, "or") == 0)
		ret_str = "-o";
	else if( strcmp( expr, "and") == 0)
		ret_str = "-a";
	else if( strcmp( expr, "==") == 0)
		ret_str = "=";
	else
		ret_str = expr;

	return ret_str;
}

PRIVATE void dump_expr( NODE *expr)
{
	if( expr == NULL)
	{
		fprintf( stderr, "expr is null");
		return;
	}

	if( expr->type == T_EXPR)
	{
		switch( expr->expr_type)
		{
		case T_AND:
		case T_OR:
			dump_expr( expr->left);
			fprintf( yyout, "%s ", translate_expr( expr->name));
			dump_expr( expr->right);
			break;
		case T_COMPR:
			dump_expr( expr->left);
			fprintf( yyout, "%s ", translate_expr( expr->name));
			dump_expr( expr->right);
			break;
		case T_NOT:
			fprintf( yyout, "! ");
			dump_expr( expr->left);
			break;
		default:
			fprintf( stderr, "Unknown expr type %d\n", expr->expr_type);
			return;
		}
	}
	else
	{
		switch( expr->type)
		{
		case T_STR:
		case T_INT:
		case T_CONST:
			fprintf( yyout, "%s ", expr->name);
			break;
		default:
			fprintf( stderr, "bad expr type of %d\n", expr->type);
		}
	}
}

PUBLIC void dump_code( LISTHEAD *localvars, NODE *code)
{
	NODE *args;
	VARTYPE *var_ptr;
	char *typeset;
	int count;

	debug( code->lineno, "begin dump_code %s\n", code->name);

	switch( code->type)
	{
	case T_BLOCK:
		dump_block( code);
		break;
	case T_STATEM:
		dump_statem( code);
		fprintf( yyout, "\n");
		break;
	case T_LOOP:
		dump_statem( code->args);
		fprintf( yyout, " | ");
		fprintf( yyout, "while read %s\n" , code->name);
		fprintf( yyout, "do\n");
		JUMPUP
		dump_code( localvars, code->code);
		JUMPBK
		fprintf( yyout, "done\n");
		break;
	case T_PIPE:
		dump_statem( code->code);
		fprintf( yyout, " %s " ,code->name);
		break;
	case T_EQUALS:
		if((var_ptr = find_var(localvars, code->name)) == NULL)
		{
			if((var_ptr = find_var(global_var, code->name)) == NULL)
				fprintf( stderr, "%s %d: Assign to unknown %s\n", code->file_name, code->lineno, code->name);
		}
		if( var_ptr != NULL)
			if( (code->args->type < 100) &&
				(var_ptr->type != code->args->type)
			)
				fprintf( stderr, "%s %d: %s var type mismatch = %s vs %s (%s)\n", 
						code->file_name,
						code->lineno,
						code->name,
						type_to_name( var_ptr->type),
						type_to_name( code->args->type),
						code->args->name
				);

		INDENT fprintf( yyout, "%s=", code->name);
		for( count=0, args=code->args; args != NULL; args = args->next)
		{
			if( count != 0)
				fprintf( yyout, " ");
			fprintf( yyout, "%s", args->name);
			count++;
		}
		fprintf( yyout, "\n");
		break;
	case T_DOT:
		INDENT fprintf( yyout, ". %s\n", code->name);
		break;
	case T_COMMENT:
		dump_comment(code);
		break;
	case T_BLANK:
		fprintf( yyout, "\n");
		break;
	case T_GETOPT:
		dump_getopt( code->name);
		break;
	case T_CASE:
		INDENT fprintf( yyout, "case %s in\n", code->var);
		JUMPUP
		if( code->options != NULL)
			dump_options( localvars, code->options);
		JUMPBK
		tab_level( level); fprintf( yyout, "esac\n");
		break;
	case T_FOR:
		INDENT fprintf( yyout, "for %s in %s\n", code->variable, code->value);
		INDENT fprintf( yyout, "do\n");
		JUMPUP
		dump_code_chain( localvars, code->code);
		JUMPBK
		INDENT fprintf( yyout, "done\n");
		break;
	case T_IF:
		INDENT fprintf( yyout, "if ");
		if( code->test_str->type == T_STRING)
			fprintf( yyout, "%s", code->test_str->name);
		else
		{
			/* got an expr to eval */
			fprintf( yyout, "[ ");
			dump_expr( code->test_str);
			fprintf( yyout, "]");
		}
		fprintf( yyout, "; then\n");
		JUMPUP
		dump_code_chain( localvars, code->code);
		JUMPBK

		if( code->elifp != NULL)
			dump_elif( localvars, code->elifp);

		if( code->elsep != NULL)
		{
			INDENT fprintf( yyout, "else\n");
			JUMPUP
			dump_code_chain( localvars, code->elsep);
			JUMPBK
		}

		INDENT fprintf( yyout, "fi\n");
		break;
	case T_WHILE:
		INDENT fprintf( yyout, "%s", code->name);
		for( args = code->args; args != NULL; args = args->next)
		{
			if( args->type != T_EXPR)
				fprintf( yyout, " %s", args->name);
	                else
			{
				/* got an expr to eval */
				fprintf( yyout, " [ ");
				dump_expr( args);
				fprintf( yyout, "]");
			}
		}
		fprintf( yyout, "\n");
		INDENT fprintf( yyout, "do\n");
		JUMPUP
		if( code->code != NULL)
			dump_code_chain( localvars, code->code);
		JUMPBK
		INDENT fprintf( yyout, "done\n");
		break;
	case T_DECLARE:
		dump_decl( localvars, code);
		break;
	case T_FUNC:
		if( find_func( code->name) != NULL)
		{
			INDENT fprintf( yyout, "%s ", code->name);
			dump_func_args( code->name, code->func_args);
			fprintf( yyout, "\n");
		}
		else
		{
			INDENT fprintf( yyout, "%s()\n", code->name);
			fprintf( stderr, "%s %d: can't find %s()\n", code->file_name, code->lineno,code->name);
		}
		break;
	default:
		fprintf( yyout, "dump_code: unknown type %d\n", code->type);
		exit(1);
	}

	debug( 0, "end dump_code\n", NULL);
}

PUBLIC void do_tran( struct node_struct *prog)
{

	struct node_struct *ptr;
	LISTHEAD *local_var;
	int x=0;

	debug( 0, "begin do_tran\n", NULL);

	level = 0;
	for( ptr = prog; ptr != NULL; ptr = ptr->next)
	{
		if( ptr->type == T_PROC )
		{
			local_var = start_scope();

			fprintf( yyout, "%s() {\n", ptr->name);

			JUMPUP
			dump_args( local_var, ptr->args);
			add_func_args( ptr->name, ptr->args);
			dump_code_chain( local_var, ptr->code);
			JUMPBK

			local_var = end_scope( local_var);

			fprintf( yyout, "}\n");
		} else if( ptr->type == T_EXTERN )
			add_func_args( ptr->name, ptr->args);
		else if( ptr->type == T_GLOBAL )
			add_var_list( NULL, global_var, ptr->name, T_STR);
		else
			dump_code( NULL, ptr);
		x++;
	}

	debug( 0, "done do_tran\n", NULL);
}

PUBLIC void start_tran( char *output_type, struct node_struct *prog)
{
	int i;

	g_output_type = output_type;

	debug( 0, "begin start_tran\n", NULL);

	DOPROBE( do_tran, prog)

	global_var = start_scope();
	add_var( global_var, "PATH", T_STR);
	add_var( global_var, "HOME", T_STR);

	do_tran( prog);

	if( do_summary)
        {
                tracker_summary( global_var);
                summary_prop();
        }

	global_var = end_scope( global_var);

	debug( 0, "done start_tran\n", NULL);
}
