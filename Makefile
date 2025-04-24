lex:
	flex Lexer.l
	gcc lex.yy.c -o lexer -lfl
	./lexer