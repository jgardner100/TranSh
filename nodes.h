NODE *create_node( char *name, NODE *next, int type);
NODE *code_node( char *name, NODE *next, int type, NODE *args, NODE *code);
NODE *value_node( char *string, int type);
NODE *case_node( NODE *next, char *var, NODE *options);
NODE *option_node( NODE *opt_list, NODE *code, NODE *next);
NODE *if_node(NODE *next, NODE *test_str, NODE *code, NODE *elifp, NODE *elsep);
NODE *for_node( NODE *next, char *variable, char *value, NODE *code);
NODE *decl_node( char *name, NODE *var_type, NODE *var_value, NODE *var_list);
NODE *param_node( char *name, NODE *var_type, NODE *next);
NODE *func_node( char *name, NODE *func_args);
NODE *expr_node( char *string, int type, NODE *left, NODE *right);