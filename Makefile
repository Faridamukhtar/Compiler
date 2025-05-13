CC=gcc
CFLAGS=-Wall -g

all: 
	clear
	make compiler

compiler: lex.yy.c parser.tab.c symbol_table.c
	$(CC) $(CFLAGS) -o compiler lex.yy.c parser.tab.c symbol_table.c helpers.c

parser.tab.c parser.tab.h: parser.y
	bison -d parser.y

lex.yy.c: lexer.l parser.tab.h
	flex lexer.l

clean:
	rm -f compiler lex.yy.c parser.tab.c parser.tab.h *.o

run:
	./compiler < test/input.txt
