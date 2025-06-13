CC=gcc
CFLAGS=-Wall -g -Wno-unused-function

all: 
	clear
	make compiler

compiler: lex.yy.c parser.tab.c src/symbol_table.c
	$(CC) $(CFLAGS) -o compiler lex.yy.c parser.tab.c src/symbol_table.c src/paramater.c src/helpers.c src/error_handler.c src/quadruple.c src/quad_to_asm.c -Iinclude

parser.tab.c parser.tab.h: parser.y
	bison -d parser.y

lex.yy.c: lexer.l parser.tab.h
	flex --header-file=lex.yy.h -o lex.yy.c Lexer.l

clean:
	rm -f compiler lex.yy.c parser.tab.c parser.tab.h *.o *.txt

run:
	./compiler < test/input.txt