%{
#include <stdio.h>
%}

DIGIT   [0-9]
ID      [a-zA-Z_][a-zA-Z0-9_]*
TYPE    int|float|bool|string|void
%%
"if"            { printf("IF\n"); }
"then"          { printf("THEN\n"); }
"else"          { printf("ELSE\n"); }
"repeat"        { printf("REPEAT\n"); }
"until"         { printf("UNTIL\n"); }
"switch"        { printf("SWITCH\n"); }
"case"          { printf("CASE\n"); }
"default"       { printf("DEFAULT\n"); }
"function"      { printf("FUNCTION\n"); }
"return"        { printf("RETURN\n"); }

"and"           { printf("AND\n"); }
"or"            { printf("OR\n"); }
"not"           { printf("NOT\n"); }

"=="            { printf("EQ\n"); }
"!="            { printf("NEQ\n"); }
">="            { printf("GTE\n"); }
"<="            { printf("LTE\n"); }
">"             { printf("GT\n"); }
"<"             { printf("LT\n"); }

"+"             { printf("PLUS\n"); }
"-"             { printf("MINUS\n"); }
"*"             { printf("MUL\n"); }
"/"             { printf("DIV\n"); }
"^"             { printf("EXP\n"); }

"="             { printf("ASSIGN\n"); }
";"             { printf("SEMI\n"); }
":"             { printf("COLON\n"); }
","             { printf("COMMA\n"); }
"("             { printf("LPAREN\n"); }
")"             { printf("RPAREN\n"); }
"{"             { printf("LBRACE\n"); }
"}"             { printf("RBRACE\n"); }

{TYPE}          { printf("TYPE: %s\n", yytext); }
{DIGIT}+        { printf("NUMBER: %s\n", yytext); }
{ID}            { printf("IDENTIFIER: %s\n", yytext); }
[ \t\r\n]+      { }
.               { printf("UNKNOWN: %s\n", yytext); }
%%

int main() {
    yylex();
    return 0;
}
