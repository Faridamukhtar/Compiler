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
STRING      \"([^\"\\]|\\.)*\"
CHAR        \'([^\'\\]|\\.)*\'

%%

"if"            { return IF; }
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
"continue"      { return CONTINUE; }
"const"         { return CONST; }
"break"         { return BREAK; }

"and"           { return AND; }
"or"            { return OR; }
"not"           { return NOT; }

"=="            { return EQ; }
"!="            { return NEQ; }
">="            { return GTE; }
"<="            { return LTE; }
">"             { return GT; }
"<"             { return LT; }
"%"             { return MOD; }

"+"             { return PLUS; }
"++"            { return INC; }
"-"             { return MINUS; }
"--"            { return DEC; }
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
{STRING}        { return STRING; }
{CHAR}          { return CHAR; }
{ID}            { return IDENTIFIER; }

[ \t\r\n]+      { /* skip whitespace */ }
\/\/.*          { /* skip single-line comments */ }
\/\*[^*]*\*+([^/*][^*]*\*+)*\/ { /* skip multi-line comments */ }
.               { return UNKNOWN; }

%%
int yywrap() {
    return 1;
}
