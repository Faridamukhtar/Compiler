%{
#include <stdio.h>
#include "parser.tab.h"  // Yacc header to recognize token values
%}

DIGIT       [0-9]
LETTER      [a-zA-Z]
ID          [a-zA-Z_][a-zA-Z0-9_]*
TYPE        int|float|bool|string|void
INT         {DIGIT}+
FLOAT       {DIGIT}+"."{DIGIT}+
BOOL        true|false

%%

"if"            { return IF; }
"then"          { return THEN; }
"else"          { return ELSE; }
"repeat"        { return REPEAT; }
"until"         { return UNTIL; }
"while"         { return WHILE; }
"for"           { return FOR; }
"switch"        { return SWITCH; }
"case"          { return CASE; }
"default"       { return DEFAULT; }
"function"      { return FUNCTION; }
"return"        { return RETURN; }
"const"         { return CONST; }

"and"           { return AND; }
"or"            { return OR; }
"not"           { return NOT; }

"=="            { return EQ; }
"!="            { return NEQ; }
">="            { return GTE; }
"<="            { return LTE; }
">"             { return GT; }
"<"             { return LT; }

"+"             { return PLUS; }
"-"             { return MINUS; }
"*"             { return MUL; }
"/"             { return DIV; }
"^"             { return EXP; }

"="             { return ASSIGN; }
";"             { return SEMI; }
":"             { return COLON; }
","             { return COMMA; }
"("             { return LPAREN; }
")"             { return RPAREN; }
"{"             { return LBRACE; }
"}"             { return RBRACE; }

{TYPE}          { return TYPE; }
{FLOAT}         { return FLOAT; }
{INT}           { return INT; }
{BOOL}          { return BOOLEAN; }
{ID}            { return IDENTIFIER; }

[ \t\r\n]+      { /* skip whitespace */ }
.               { return UNKNOWN; }

%%

int main() {
    yylex();
    return 0;
}
