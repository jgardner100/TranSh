CC=gcc
CFLAGS=-Wno-format-security -g

SOURCES=main.c linux.c solaris.c tran.c free.c block.c tracker.c prop.c \
	list.c file.c

OBJECTS=$(SOURCES:.c=.o)
EXECUTABLE=mysh

all:	$(SOURCES) $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS) mysh.l mysh.y mysh.tab.h
	gcc -c lex.yy.c
	gcc -c mysh.tab.c
	gcc $(OBJECTS) lex.yy.o mysh.tab.o -o $(EXECUTABLE)

clean:
	rm -f *.o lex.yy.c mysh.tab.c mysh.tab.h $(EXECUTABLE)

main.o:	main.c mysh.h
tran.o:	tran.c mysh.h
linux.o:	linux.c mysh.h
solaris.o:	solaris.c mysh.h
free.o:	free.c mysh.h
block.o:	block.c mysh.h
tracker.o:	tracker.c mysh.h
prop.o:	prop.c mysh.h
list.o:	list.c mysh.h
file.o:	file.c mysh.h
mysh.tab.h:     mysh.l mysh.y
	flex mysh.l
	bison -d mysh.y
