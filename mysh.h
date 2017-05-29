#define VERSION "1.0 pl 17"

#define PRIVATE static
#define PUBLIC

#define TRUE 1
#define FALSE 0

#define LEN(x,y) ((int)(sizeof(x)/sizeof(y)))

#define INDENT tab_level( level);
#define INDENTB(CODE) {tab_level( level); CODE }
#define JUMPUP level++;
#define JUMPBK level--;

#define T_PROC    1
#define T_STATEM  2
#define T_FOR     3
#define T_EQUALS  4
#define T_DOT     5
#define T_IF      6
#define T_EXPR    7
#define T_COMMENT 8
#define T_DIRECT  9
#define T_BLANK   10
#define T_GETOPT  11
#define T_COMPARE 12
#define T_JOIN    13
#define T_CHECK   14
#define T_NOT     15
#define T_VALUE   16
#define T_CASE    17
#define T_OPTION  18
#define T_STRING  19
#define T_REDIR   20
#define T_PIPE    21
#define T_WHILE   22
#define T_LOOP    23
#define T_BLOCK   24
#define T_DECLARE 25
#define T_FUNC    26

#define T_STR     27
#define T_INT     28
#define T_CONST   29
#define T_ALL     30
#define T_EXTERN  31
#define T_GLOBAL  32

typedef struct node_struct {
        char *name;
	char *func_name;
	char *token;
	int type;

	int lineno;
	char *file_name;

	struct node_struct *next;

	/* for case statements */
	char *var;
	struct node_struct *options;

	/* switch statement */
	struct node_struct *opt_list;

	/* for if statements */
	char *test_str;
	struct node_struct *elsep;

	char *elif_str;
	struct node_struct *elifp;

	/* for for proc args */
	struct node_struct *var_type;
	struct node_struct *var_value;
	struct node_struct *var_list;

	/* for for statements */
	char *variable;
	char *value;

	/* for func calls */
	struct node_struct *func_args;

	/* for procs */
	struct node_struct *args;
	struct node_struct *code;
} NODE;

typedef struct listnode_struct {
        struct listnode_struct *next;
        char *name;
        char *value;
        void *content;
	int content_count;
} LISTNODE;

typedef struct listhead {
        LISTNODE *start;
        char *name;
} LISTHEAD;

typedef struct buffer_struct {
	char *string;
	long size;
} BUFFER;

extern int lineno;
extern char *file_name;

void start_tran( char *output_type, struct node_struct *prog);
void do_free( struct node_struct *prog);
void debug( int linenum, char *fmt, char *msg);
void init_lex( int p_lineno, char *p_filename);

/* Parser support funcs*/
typedef struct yy_buffer_state *YY_BUFFER_STATE;
extern int yyparse();
extern YY_BUFFER_STATE yy_scan_string(char *str);
extern void yy_delete_buffer( YY_BUFFER_STATE buffer);
extern FILE *yyout;

/* translation support */
extern int level;
extern void tab_level( int tab_level);
extern void dump_args( LISTHEAD *localvars, NODE *arg);
extern void dump_code_chain( LISTHEAD *localvars, NODE *code);
extern void dump_code( LISTHEAD *localvars, NODE *code);
extern void dump_getopt( char *options);
extern void dump_elif( LISTHEAD *localvars, NODE *code);
extern void dump_options_values( NODE *opt_list);
extern void dump_options( LISTHEAD *localvars, NODE *code);
extern void dump_statem( NODE *code);
extern void dump_block( NODE *code);
extern void start_tran( char *output_type, NODE *prog);
extern char *strip_cr( char *line);
extern char *strip_str( char *str);

/* for tracking types */
extern void add_func( char *func_name);
extern void add_func_args( char *func_name, NODE *args);
extern char *find_func_name( char *func_name);
extern LISTNODE *find_func( char *func_name);
extern void add_var( LISTHEAD *chain, char *var_name, int type);
extern char *find_var( LISTHEAD *chain, char *var_name);
extern void init_tracker(void);
extern void close_tracker(void);
extern void tracker_summary( LISTHEAD *global_chain);
extern LISTHEAD *start_scope( void);
extern LISTHEAD *end_scope( LISTHEAD *chain);

/* tracking property */
extern int do_summary;
extern void init_prop(void);
extern void close_prop(void);
extern void add_prop( char *prop_name, char *prop_value);
extern char *get_prop( char *name);
extern void summary_prop(void);

/* list handling */
extern void list_insert( LISTHEAD *head, char *name, char *value, void *content, int count);
extern LISTHEAD *list_start( void);
extern void list_destroy( LISTHEAD *head);
extern LISTNODE *list_get( LISTHEAD *head, char *name);
extern void dump_list( LISTHEAD *head);
extern void check_func_args( char *fname, NODE *args);

/* file handling */
extern BUFFER *open_file( char *fname);
extern void process_file( BUFFER *buf);
extern void close_file(BUFFER *buf);
extern int preprocess_file( BUFFER *buf);

#define DOPROBE(NAME,ARG) \
	for(i=0;i<(sizeof(probes)/sizeof(struct probe_struct));i++) \
        { \
                if( strcmp( g_output_type, probes[i].type_name) == 0) \
                { \
                        if( probes[i].NAME != NULL) \
                        { \
                                probes[i].NAME( ARG); \
                                return; \
                        } \
                } \
        }
