%{
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include "TranSh.tab.h"

#define LEN(x,y) (sizeof(x)/sizeof(y))

extern char *strip_cr( char *line);
extern char *strip_str( char *str);

void debug( int lineno, char *fmt, char *msg);

int lineno=0;
char *file_name=NULL;

struct keyw_struct {
        char *word;
        int token;
} keywords[] = {
        {"for", FOR }
        ,{"do", DO }
        ,{"done", DONE }
        ,{"case", CASE }
        ,{"esac", ESAC }
        ,{"in", IN }
        ,{"if", IF }
        ,{"then", THEN }
        ,{"else", ELSE }
        ,{"elif", ELIF }
        ,{"fi", FI }
        ,{"while", WHILE }
        ,{"proc", PROC }
        ,{"getopt", GETOPT }
        ,{"read", READ }
        ,{"loop", LOOP }
        ,{"extern", EXTERN }
        ,{"global", GLOBAL }

        ,{"str", TYPE_STR }
        ,{"int", TYPE_INT }
        ,{"all", TYPE_ALL }
        ,{"const", TYPE_CONST }

        ,{"and", AND }
        ,{"or", OR }
        ,{"not", NOT }

        ,{"do_init", BLOCK }
        ,{"do_finish", BLOCK }
};

typedef struct keyw_struct KEYW;

void init_lex( int p_lineno, char *p_filename)
{
	static char buffer[128];

	sprintf( buffer, "init_lex(): %d %s\n", p_lineno, p_filename);
	debug( lineno, buffer, NULL);
	lineno = p_lineno;
	file_name = strdup( p_filename);
}

int count_cr( char *str)
{
	int ptr, i = 0;

	for( ptr = 0; str[ptr] != '\0'; ptr++)
		if( str[ptr] == '\n')
			i++;

	return i;
}

//
// Check for a directive and carry it out if we find one
//
void check_dir( char *comment)
{
	static char buffer[521];
	static char msg[521];
	char *str, *str_lineno, *str_file;
	int lno;

	strcpy( buffer, comment);
	str = strtok( buffer, " ,");

	//	
	// Line directive to set filename & line number
	//
	if( strcmp( str, "#line") == 0)
	{
		str_lineno = strtok( NULL, " ,");
		str_file = strip_str(strip_cr(strtok( NULL, " ,")));
		lno = atoi( str_lineno);
		sprintf( msg, "got #line lineno of %d\n", lno);
		debug( lineno, msg, NULL);

		init_lex( lno, str_file);
	}
}

int lookup( char *str)
{
        int i;
        char buffer[256];

        for( i = 0; (str[i] != '\0') && i < LEN(buffer,char); i++)
                buffer[i] = tolower( str[i]);
        buffer[i] = '\0';

        for( i = 0; i < LEN(keywords,KEYW); i++)
                if( strcmp( buffer, keywords[i].word) == 0)
		{
			debug( lineno, "Got lookup keyword %s\n", buffer);
                        return keywords[i].token;
		}

        return STRING;
}

%}
%%
[\-0-9][0-9]*           { yylval.string = strdup(yytext);return NUMBER;}
\.			{ debug(lineno, NULL,"DOT"); return DOT;}
\{			{ debug(lineno, NULL,"Got lbrak"); return LBRAK;}
\}			{ debug(lineno, NULL,"Got rbrak"); return RBRAK;}
\(			{ debug(lineno, NULL,"LPAR"); return LPAR;}
\)			{ debug(lineno, NULL,"RPAR"); return RPAR;}
"$("			{ debug(lineno, NULL, "got exec"); return EXEC;}

"=="			{ yylval.string = strdup(yytext); debug(lineno,  NULL, "got equals"); return COMPR;}
"!="			{ yylval.string = strdup(yytext); debug(lineno,  NULL, "got not equals"); return COMPR;}
"<"			{ yylval.string = strdup(yytext); debug(lineno,  NULL, "got lessthan"); return COMPR;}
">"			{ yylval.string = strdup(yytext); debug(lineno,  NULL, "got greaterthan"); return COMPR;}

"="			{ debug(lineno,  NULL, "got equals"); return EQUALS;}
\;\;			{ debug(lineno, NULL,"got double semicolon"); return DSEMIC;}
\;			{ debug(lineno, NULL,"got semicolon"); return SEMIC;}
\,			{ debug(lineno, NULL,"got comma"); return COMMA;}
\n                      { lineno++; } /* Count the lines */ 
^[ \t]+\n               { debug(lineno, NULL,"BLANK LINE!!"); lineno++; return BLANK; }
\n[ \t]*\n              { debug(lineno, NULL,"BLANK LINE!!"); lineno+=2; return BLANK; }
\|			{ debug(lineno, NULL,"got pipe"); return PIPE;}
\*			{ debug(lineno, NULL,"STAR"); return STAR;}
[ \t]+                  /* ignore whitespace */;

\<\<[a-zA-Z0-9/\._ \n\*"|"$]*\>	{ debug(lineno, "str=|redir %s|\n",yytext); yylval.string = strdup(yytext); return REDIRSTRING;}

-[a-zA-Z][a-zA-Z0-9/\._]*	{ debug(lineno, "str=|dash %s|\n",yytext); yylval.string = strdup(yytext); return lookup(yytext);}

\>[a-zA-Z0-9/\._\}\*${]*	{ debug(lineno, "str=|redir %s|\n",yytext); yylval.string = strdup(yytext); return lookup(yytext);}

$[a-zA-Z0-9#?\{\*][a-zA-Z0-9/\._\-\}\*${]*	{ debug(lineno, "str=|var %s|\n",yytext); yylval.string = strdup(yytext); return lookup(yytext);}

\>\>	{ debug(lineno, "str=|eos >> %s|\n",yytext); yylval.string = strdup(yytext); return lookup(yytext);}

[a-zA-Z/][a-zA-Z0-9/\._\*]*	{ debug(lineno, "str=|word %s|\n",yytext); yylval.string = strdup(yytext); return lookup(yytext);}

\'(\\.|[^'`])*\'         { debug(lineno, "single quote |%s|\n",yytext); lineno += count_cr(yytext); yylval.string = strdup(yytext);return STRING;}

\"(\\.|[^"])*\"         { debug(lineno, "double quote |%s|\n",yytext); lineno += count_cr(yytext); yylval.string = strdup(yytext);return STRING;}

\`(\\.|[^`])*\`         { debug(lineno, "single backquote |%s|\n",yytext); lineno += count_cr(yytext); yylval.string = strdup(yytext);return STRING;}

\$\((\\.|[^\)])*\)         { debug(lineno, "|exec %s|\n",yytext); lineno += count_cr(yytext); yylval.string = strdup(yytext);return EXECSTRING;}

\[(\\.|[^\]])*\]         { debug(lineno, "|test %s|\n",yytext); lineno += count_cr(yytext); yylval.string = strdup(yytext);return TESTSTRING;}

#.*\n			{ debug(lineno, "comment |%s|\n",strip_cr(yytext)); lineno++; check_dir(yytext); yylval.string = strdup(yytext);return COMMENT;}
%%
