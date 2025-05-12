%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parser.tab.h"  // Bison header with token and yylval declarations
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

{TYPE}          { yylval.s = strdup(yytext); return TYPE; }
{FLOAT}         { yylval.f = atof(yytext); return FLOAT; }
{INT}           { yylval.i = atoi(yytext); return INT; }
{BOOL}          { yylval.i = (strcmp(yytext, "true") == 0); return BOOLEAN; }
{STRING}        { yylval.s = strdup(yytext); return STRING; }
{CHAR}          { yylval.c = yytext[1]; return CHAR; }
{ID}            { yylval.s = strdup(yytext); return IDENTIFIER; }
[ \t\r\n]+      { /* skip whitespace */ }
\/\/.*          { /* skip single-line comments */ }
\/\*[^*]*\*+([^/*][^*]*\*+)*\/ { /* skip multi-line comments */ }
.               { return UNKNOWN; }

%%
int yywrap() {
    return 1;
}
