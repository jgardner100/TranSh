%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "TranSh.h"
#include "nodes.h"

extern int yylex();
extern char *yytext;
extern struct node_struct *prog;
extern int lineno;

void yyerror(const char *str)
{
        fprintf(stderr,"Line %d: error: %s token: %s\n", lineno, str, yytext);
}
 
int yywrap()
{
        return 1;
} 
 
%}

%token PROC LBRAK RBRAK LPAR RPAR SEMIC DSEMIC DOT EQUALS NOTEQUALS LSQUARE
%token RSQUARE EXEC FOR IN DO DONE CASE ESAC IF THEN ELSE ELIF FI BLANK
%token GETOPT COMMA PIPE STAR WHILE READ LOOP TYPE_STR TYPE_INT TYPE_CONST
%token TYPE_ALL EXTERN GLOBAL AND OR NOT
%token <string> STRING NUMBER COMMENT TESTSTRING EXECSTRING REDIRSTRING BLOCK
%token <string> SYSCODE

%type <node> proc_args statements statement statem_args func_params
%type <node> else_part elif_parts case_parts case_opt_list type values
%type <node> expr declare_list declare_element teststr

%union {
	char *string;
	struct node_struct *node;
}

%start commands

%%

commands:
        | commands statement
        {
                if( prog == NULL)
                        prog = $2;
                else
                {
                        struct node_struct *ptr;

                        ptr = prog;
                        while( ptr->next != NULL)
                                ptr = ptr->next;

                        ptr->next = $2;
                }
        }
        ;

values:
	STRING
		{ $$ = value_node( strdup($1), T_STR); }
	| NUMBER
		{ $$ = value_node( strdup($1), T_INT); }
	| SYSCODE
		{ $$ = value_node( strdup($1), T_INT); }
	;

expr:
	values
		{ $$ = $1; }
	| values EQUALS expr
		{ $$ = expr_node( "=", T_EQUALS, $1, $3); }
	| values NOTEQUALS expr
		{ $$ = expr_node( "!=", T_NOTEQUALS, $1, $3); }
	| NOT expr
		{ $$ = expr_node( "not", T_NOT, $2, NULL); }
	;
	
statements: {$$=NULL;}
	| statement statements { $1->next = $2; $$=$1; }
	;

declare_element: STRING
		{ 
			NODE *ptr;

			ptr = create_node( strdup($1), NULL, T_DECLARE);
			ptr->var_value = NULL;

			$$ = ptr;
		}
	| STRING EQUALS values
		{ 
			NODE *ptr;

			ptr = create_node( strdup($1), NULL, T_DECLARE);
			ptr->var_value = $3;

			$$ = ptr;
		}
	;

declare_list: declare_element
		{ $$ = $1; }
	| declare_element COMMA declare_list
		{ 
			NODE *ptr;

			ptr = $1;
			ptr->next = $3;
			$$ = ptr;
		}
	;

teststr:
	TESTSTRING
		{ $$ = value_node( $1, T_STRING);}
	| LBRAK expr RBRAK
		{ $$ = $2; }
	;

statement: STRING statem_args SEMIC
		{ $$ = code_node( strdup($1), NULL, T_STATEM, $2, NULL); }
	| PROC STRING LPAR proc_args RPAR LBRAK statements RBRAK
		{ $$ = code_node( strdup($2), NULL, T_PROC, $4, $7); }
	| EXTERN STRING LPAR proc_args RPAR SEMIC
		{ $$ = code_node( strdup($2), NULL, T_EXTERN, $4, NULL); }

	| GLOBAL type STRING SEMIC
		{ $$ = code_node( strdup($3), NULL, T_GLOBAL, NULL, NULL); }

	| type declare_list SEMIC
		{ $$ = decl_node( "decl list", $1, NULL, $2); }

	| GETOPT STRING SEMIC
		{ $$ = value_node( $2, T_GETOPT); }
	| BLOCK
		{ $$ =  code_node( strdup($1), NULL, T_BLOCK, NULL, NULL); }
	| statement PIPE
		{ $$ =  code_node( "|", NULL, T_PIPE, NULL, $1); }
	| STRING EQUALS EXECSTRING SEMIC
		{ $$ = code_node( strdup($1), NULL, T_EQUALS, value_node( strdup($3),STRING), NULL); }
	| STRING EQUALS values SEMIC
		{ $$ = code_node( strdup($1), NULL, T_EQUALS, $3, NULL); }
	| FOR STRING IN STRING DO statements DONE
		{ $$ = for_node( NULL, $2, $4, $6); }
	| DOT STRING SEMIC
		{ $$ = create_node( strdup($2), NULL, T_DOT); }
	| COMMENT
		{ $$ = create_node( strdup($1), NULL, T_COMMENT); }
	| BLANK
		{ $$ = create_node( "blank", NULL, T_BLANK); }
	| WHILE LPAR values RPAR DO statements DONE
		{ $$ = code_node( "while", NULL, T_WHILE, $3, $6); }
	| WHILE teststr DO statements DONE
		{ $$ = code_node( "while", NULL, T_WHILE, $2, $4); }
	| WHILE READ STRING DO statements DONE
		{
			NODE *ptr;

			ptr = value_node( "read", STRING);
			ptr->next = value_node( strdup( $3), STRING);

			$$ = code_node( "while", NULL, T_WHILE, ptr, $5);
		}
	| LOOP statement STRING DO statements DONE
		{ $$ = code_node( strdup($3), NULL, T_LOOP, $2, $5); }
	| IF teststr THEN statements elif_parts else_part FI
		{ $$ = if_node( NULL, $2, $4, $5, $6); }
	| CASE STRING IN case_parts ESAC
		{ $$ = case_node( NULL, $2, $4); }
	| STRING LPAR func_params RPAR SEMIC
		{ $$ = func_node( strdup($1), $3);}
	;

func_params: { $$=NULL;}
	| values
		{ $$=$1;}
	| values COMMA func_params
		{ 
			NODE *ptr;

			ptr = $1;
			ptr->next = $3;

			$$=ptr;
		}
	;

case_opt_list: STAR
		{ $$=value_node( strdup( "*"), STRING);}
	| STRING
		{ $$=value_node( strdup( $1), STRING);}
	| STRING PIPE case_opt_list
		{ $$=create_node( strdup( $1), $3, PIPE);}
	;

case_parts: { $$=NULL;}
	| BLANK case_parts
		{ $$=$2; }
	| case_opt_list RPAR statements DSEMIC case_parts
		{ $$=option_node( $1, $3, $5); }
	;

else_part: { $$=NULL;}
	| ELSE statements
		{$$=$2;}
	;

elif_parts: {$$=NULL;}
	| ELIF teststr THEN statements elif_parts
		{ $$ = if_node( $5, $2, $4, NULL, NULL); }
	;

statem_args: {$$=NULL;}
	| STRING statem_args
		{ $$ = create_node( strdup($1), $2, T_STR); }
	| REDIRSTRING statem_args
		{ $$ = create_node( strdup($1), $2, T_REDIR); }
	| NUMBER statem_args
		{ $$ = create_node( strdup($1), $2, T_INT); }
	| SYSCODE statem_args
		{ $$ = create_node( strdup($1), $2, T_INT); }
	;

type: TYPE_STR
		{ $$ = create_node( "str", NULL, T_STR); }
	| TYPE_INT
		{ $$ = create_node( "int", NULL, T_INT); }
	| TYPE_CONST
		{ $$ = create_node( "const", NULL, T_CONST); }
	| TYPE_ALL
		{ $$ = create_node( "all", NULL, T_ALL); }
	;

proc_args: 
	{$$=NULL;}
	| type STRING
		{ $$ = param_node( strdup($2), $1, NULL); }
	| type STRING COMMA proc_args
		{ $$ = param_node( strdup($2), $1, $4); }
	;
