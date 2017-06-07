#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "TranSh.h"

PUBLIC LISTHEAD *list_start( void)
{
	LISTHEAD *head;

	head = malloc( sizeof(LISTHEAD));
	head->start = NULL;

	return head;
}

/*
 * List handling funcs
 */
PUBLIC void list_insert( LISTHEAD *head, char *name, char *value, void *content, int count)
{
        LISTNODE *node, *ret_val, *ptr;

	if( head == NULL)
	{
		fprintf( stderr, "null head in list_insert\n");
		return;
	}

        node = (LISTNODE *)malloc( sizeof(LISTNODE));
        node->name = name;
        node->value = value;
        node->content = content;
        node->content_count = count;
        node->next = NULL;

        if( head->start != NULL)
        {
                for( ptr = head->start; ptr->next != NULL; ptr = ptr->next)
                        ;
                ptr->next = node;
        } else
                head->start = node;
}

PUBLIC void list_destroy( LISTHEAD *head)
{
        LISTNODE *ptr, *next;

	if( head == NULL)
	{
		fprintf( stderr, "null head in list_destroy\n");
		return;
	}

        next = head->start;
        while( next != NULL)
        {
                ptr = next;
                next = ptr->next;
                free( ptr);
        }
}

PUBLIC LISTNODE *list_get( LISTHEAD *head, char *name)
{
	LISTNODE *ptr;

	if( head != NULL)
	{
		for( ptr = head->start; ptr != NULL; ptr = ptr->next)
			if( strcmp( name, ptr->name) == 0)
				return ptr;
	}

	return NULL;
}

PUBLIC void dump_list( LISTHEAD *head)
{
        LISTNODE *ptr;
        int i;

	if( head == NULL)
	{
		fprintf( stderr, "null head in dump_list\n");
		return;
	}

        i = 1;
        for( ptr = head->start; ptr != NULL; ptr = ptr->next)
		if( ptr->name != NULL && ptr->value != NULL)
                	printf( "\t%d - %s = %s\n", i++, ptr->name, ptr->value);
		else if( ptr->name != NULL)
                	printf( "\t%d - %s\n", i++, ptr->name);
		else
                	printf( "\t%d - empty\n",i++);
}
