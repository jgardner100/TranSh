#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "TranSh.h"

extern YY_BUFFER_STATE yy_scan_buffer(char *base, int size);
YY_BUFFER_STATE buf_state;

PRIVATE char *alloc_str( long size)
{
	char *ptr;

	ptr = malloc( size);
	if( ptr == NULL)
	{
		fprintf( stderr, "Out of mem for string buf, len=%ld\n", size);
		exit(1);
	}

	return ptr;
}

PRIVATE BUFFER *alloc_buf( void)
{
	BUFFER *buf;

	buf = malloc( sizeof( BUFFER));
	if( buf == NULL)
	{
		fprintf( stderr, "Out of mem for buffer\n");
		exit(1);
	}

	buf->size = 0;
	buf->string = NULL;

	return buf;
}

PUBLIC BUFFER *open_file( char *fname)
{
	BUFFER *buf;
	FILE *fileHandle = NULL;

	debug( 0, "open_file(): called with %s\n", fname);

	buf = alloc_buf();

	fileHandle = fopen( fname, "rb");
	if (fileHandle == NULL) {
		perror("fopen");
		fprintf( stderr, "* Can't open [%s]\n", fname);
		return NULL;
	}

	fseek(fileHandle, 0, SEEK_END);
	buf->size = ftell(fileHandle);
	fseek(fileHandle, 0, SEEK_SET);

	// When using yy_scan_bytes, do not add 2 here ...
	buf->string = alloc_str( sizeof(char) * (buf->size + 2) );

	fread( buf->string, buf->size, sizeof(char), fileHandle);

	fclose(fileHandle);

	return buf;
}

// Simply count the carridge returns for the line numbers
int count_line( char *str, int size)
{
	int i, ret_val;

	for( ret_val = 0, i = 0; i < size; i++)
		if( str[i] == '\n')
			ret_val++;

	return ret_val;
}

/*
 * find any #include & add #file directives
 */
PUBLIC int preprocess_file( BUFFER *buf)
{
	char *ptr, *start_ptr, fname[128];
	BUFFER *include_buf;
	char *new_str;
	int i, start_len, mid_len, end_len, ret;
	int line_count;
	char file1_buf[128], file2_buf[128];
	int dir1_len, dir2_len;

	start_ptr = strstr( buf->string, "#include");
	if( start_ptr != NULL)
	{
		// find first quote mark
		for( ptr = start_ptr; *ptr != '"'; ptr++)
			;
		// now get filename
		for( ptr++, i = 0; *ptr != '"'; ptr++)
			fname[i++] = *ptr;
		fname[i] = '\0';
		ptr += 2;

		// open include file
		include_buf = open_file( fname);
		if( include_buf == NULL)
			exit(1);

		// allocate mem for new source code buffer
		new_str = alloc_str( buf->size 
					+ include_buf->size + 2
					+ 512
		);

		// tack on first code (calc how much to copy)
		start_len = start_ptr - buf->string;
		memcpy( new_str, buf->string, start_len);

		// add first #file directive
		line_count = 0;
		sprintf( file1_buf, "#line %d \"%s\"\n", line_count, fname);
		dir1_len = strlen( file1_buf);
		memcpy( new_str + start_len, file1_buf, strlen( file1_buf));

		// copy in include source code
		mid_len = include_buf->size;
		memcpy( new_str + start_len + dir1_len, include_buf->string, mid_len);

		// add second #file directive
		line_count = count_line( new_str, start_len);
		sprintf( file2_buf, "#line %d \"%s\"\n", line_count, file_name);
		dir2_len = strlen( file2_buf);
		memcpy( new_str + start_len + dir1_len + mid_len, file2_buf, dir2_len);

		// tack on rest of original source code
		end_len = buf->size - (ptr - buf->string);
		memcpy( new_str + start_len + dir1_len + mid_len + dir2_len, ptr, end_len);

		free( buf->string);
		buf->string = new_str;
		buf->size = start_len + dir1_len + mid_len + dir2_len + end_len;

		close_file( include_buf);

/*
		printf( "size = %ld\n", buf->size);
		printf( "%s\n", new_str);
*/
		ret = TRUE;
	}
	else
		ret = FALSE;

	return ret;
}

/*
 * Tell flex about the string buffer to process.
 */
PUBLIC void process_file( BUFFER *buf)
{
    // Add the two NUL terminators, required by flex.
    // Omit this for yy_scan_bytes(), which allocates, copies and
    // apends these for us.   
    buf->string[buf->size] = '\0';
    buf->string[buf->size + 1] = '\0';

    // Our input file may contain NULs ('\0') so we MUST use
    // yy_scan_buffer() or yy_scan_bytes(). For a normal C (NUL-
    // terminated) string, we are better off using yy_scan_string() and
    // letting flex manage making a copy of it so the original may be a
    // const char (i.e., literal) string.
    buf_state = yy_scan_buffer(buf->string, buf->size + 2);

    return;
}

/*
 * Free up the resources, we are finished with it.
 */
PUBLIC void close_file(BUFFER *buf)
{
	// After flex is done, tell it to release the memory it allocated.    
	yy_delete_buffer( buf_state);

	// And now we can release our (now dirty) buffer.
	free( buf->string);

	free(buf);

	return;
}
