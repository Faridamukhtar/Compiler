build-parser:
	flex --header-file=lex.yy.h -o lex.yy.c Lexer.l
	bison -d parser.y
	gcc -o parser lex.yy.c parser.tab.c src/error_handler.c -Iinclude
	./parser test/input.txt
