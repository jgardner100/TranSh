CC=gcc
CFLAGS=-Wno-format-security -g

SOURCES=main.c linux.c solaris.c tran.c free.c block.c tracker.c prop.c \
	list.c file.c

OBJECTS=$(SOURCES:.c=.o)
EXECUTABLE=TranSh

all:	$(SOURCES) $(EXECUTABLE)

$(EXECUTABLE): $(OBJECTS) TranSh.l TranSh.y TranSh.tab.h
	gcc -c lex.yy.c
	gcc -c TranSh.tab.c
	gcc $(OBJECTS) lex.yy.o TranSh.tab.o -o $(EXECUTABLE)

clean:
	rm -f *.o lex.yy.c TranSh.tab.c TranSh.tab.h $(EXECUTABLE)

main.o:	main.c TranSh.h
tran.o:	tran.c TranSh.h
linux.o:	linux.c TranSh.h
solaris.o:	solaris.c TranSh.h
free.o:	free.c TranSh.h
block.o:	block.c TranSh.h
tracker.o:	tracker.c TranSh.h
prop.o:	prop.c TranSh.h
list.o:	list.c TranSh.h
file.o:	file.c TranSh.h
TranSh.tab.h:     TranSh.l TranSh.y
	flex TranSh.l
	bison -d TranSh.y
