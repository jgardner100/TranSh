#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "TranSh.h"

extern char *yytext;
extern int lineno;

NODE *create_node( char *name, NODE *next, int type)
{
	NODE *node;

	node = (NODE *)malloc( sizeof( struct node_struct));
	if( node == NULL)
	{
		printf( "Out of mem\n");
		exit(1);
	}

	node->name = name;
	node->next = next;
	node->type = type;
	node->func_name = NULL;
	node->token = strdup(yytext);

	node->lineno = lineno;
	node->file_name = strdup( file_name);

	return node;
}

NODE *code_node( char *name, NODE *next, int type, NODE *args, NODE *code)
{
	NODE *node;

	node = create_node( name, next, type);

	node->args = args;
	node->code = code;

	return node;
}

NODE *value_node( char *string, int type)
{
	NODE *node;

	node = create_node( string, NULL, type);

	return node;
}

NODE *expr_node( char *string, int type, NODE *left, NODE *right)
{
	NODE *node;

	node = create_node( string, NULL, T_EXPR);

	node->expr_type = type;
	node->left = left;
	node->right = right;

	return node;
}

NODE *case_node( NODE *next, char *var, NODE *options)
{
	NODE *node;

	node = code_node( "case", next, T_CASE, NULL, NULL);
	node->var = var;
	node->options = options;

	return node;
}

NODE *option_node( NODE *opt_list, NODE *code, NODE *next)
{
	NODE *node;

	node = code_node( "opt", next, T_OPTION, NULL, NULL);
	node->opt_list = opt_list;
	node->code = code;

	return node;
}

NODE *if_node( NODE *next, NODE *test_str, NODE *code, NODE *elifp, NODE *elsep)
{
	NODE *node;

	node = code_node( "if", next, T_IF, NULL, NULL);

	node->test_str = test_str;
	node->code = code;
	node->elsep = elsep;
	node->elifp = elifp;

	return node;
}

NODE *for_node( NODE *next, char *variable, char *value, NODE *code)
{
	NODE *node;

	node = code_node( "for", next, T_FOR, NULL, code);

	node->variable = variable;
	node->value = value;

	return node;
}

NODE *decl_node( char *name, NODE *var_type, NODE *var_value, NODE *var_list)
{
	NODE *node;

	node = code_node( name, NULL, T_DECLARE, NULL, NULL);

	node->var_type = var_type;
	node->var_value = var_value;
	node->var_list = var_list;

	return node;
}

NODE *param_node( char *name, NODE *var_type, NODE *next)
{
	NODE *node;

	node = code_node( name, next, T_STRING, NULL, NULL);

	node->var_type = var_type;

	return node;
}

NODE *func_node( char *name, NODE *func_args)
{
	NODE *node;

	node = code_node( name, NULL, T_FUNC, NULL, NULL);
	node->func_args = func_args;

	return node;
}
