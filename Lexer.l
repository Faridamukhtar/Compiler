%{
#include <stdio.h>
#include <stdlib.h>
#include "parser.tab.h" 
#include <string.h>
#include "error_handler.h"
#include "symbol_table.h"

extern int yylineno;
int last_valid_line = 1;
int prev_valid_line = 1;

int current_column = 1;
// Tell Flex how to update the token's location
#define YY_USER_ACTION \
    yylloc.first_line = yylloc.last_line = yylineno; \
    yylloc.first_column = current_column; \
    yylloc.last_column = current_column + yyleng - 1; \
    current_column += yyleng;



%}

%option yylineno noyywrap

DIGIT       [0-9]
LETTER      [a-zA-Z]
ID          [a-zA-Z_][a-zA-Z0-9_]*
TYPE        int|float|bool|string|void|char
INT         {DIGIT}+
FLOAT       {DIGIT}+"."{DIGIT}+
BOOL        true|false
STRING      \"([^\"\\]|\\.)*\" 
CHAR        \'([^\'\\]|\\.)*\'

%%

"if"            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return IF; }
"else"          { prev_valid_line = last_valid_line; last_valid_line = yylineno; return ELSE; }
"repeat"        { prev_valid_line = last_valid_line; last_valid_line = yylineno; return REPEAT; }
"until"         { prev_valid_line = last_valid_line; last_valid_line = yylineno; return UNTIL; }
"while"         { prev_valid_line = last_valid_line; last_valid_line = yylineno; return WHILE; }
"for"           { prev_valid_line = last_valid_line; last_valid_line = yylineno; return FOR; }
"switch"        { prev_valid_line = last_valid_line; last_valid_line = yylineno; return SWITCH; }
"case"          { prev_valid_line = last_valid_line; last_valid_line = yylineno; return CASE; }
"default"       { prev_valid_line = last_valid_line; last_valid_line = yylineno; return DEFAULT; }
"function"      { prev_valid_line = last_valid_line; last_valid_line = yylineno; return FUNCTION; }
"return"        { prev_valid_line = last_valid_line; last_valid_line = yylineno; return RETURN; }
"continue"      { prev_valid_line = last_valid_line; last_valid_line = yylineno; return CONTINUE; }
"const"         { prev_valid_line = last_valid_line; last_valid_line = yylineno; return CONST; }
"break"         { prev_valid_line = last_valid_line; last_valid_line = yylineno; return BREAK; }

"and"           { prev_valid_line = last_valid_line; last_valid_line = yylineno; return AND; }
"or"            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return OR; }
"not"           { prev_valid_line = last_valid_line; last_valid_line = yylineno; return NOT; }

"=="            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return EQ; }
"!="            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return NEQ; }
">="            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return GTE; }
"<="            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return LTE; }
">"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return GT; }
"<"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return LT; }
"%"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return MOD; }

"++"            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return INC; }
"--"            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return DEC; }
"+"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return PLUS; }
"-"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return MINUS; }
"*"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return MUL; }
"/"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return DIV; }
"^"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return EXP; }

"="             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return ASSIGN; }
";"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return SEMI; }
":"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return COLON; }
","             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return COMMA; }
"("             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return LPAREN; }
")"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return RPAREN; }
"{"             { addScope(); prev_valid_line = last_valid_line; last_valid_line = yylineno; return LBRACE; }
"}"             { removeScope(); prev_valid_line = last_valid_line; last_valid_line = yylineno; return RBRACE; }

{TYPE}          { yylval.s = strdup(yytext); prev_valid_line = last_valid_line; last_valid_line = yylineno; return TYPE; }
{FLOAT}         { yylval.f = atof(yytext); prev_valid_line = last_valid_line; last_valid_line = yylineno; return FLOAT; }
{INT}           { yylval.i = atoi(yytext); prev_valid_line = last_valid_line; last_valid_line = yylineno; return INT; }
{BOOL}          { yylval.i = (strcmp(yytext, "true") == 0); prev_valid_line = last_valid_line; last_valid_line = yylineno; return BOOLEAN; }
{STRING}        { yylval.s = strdup(yytext); prev_valid_line = last_valid_line; last_valid_line = yylineno; return STRING; }
{CHAR}          { yylval.c = yytext[1];prev_valid_line = last_valid_line; last_valid_line = yylineno; return CHAR; }
{ID}            { yylval.s = strdup(yytext); prev_valid_line = last_valid_line; last_valid_line = yylineno; return IDENTIFIER; }

[ \t\r]+        { /* skip whitespace */ }
\n              { /* let yylineno increment automatically */ }


\/\/.*          { /* skip single-line comments */ }
\/\*[^*]*\*+([^/*][^*]*\*+)*\/ { /* skip multi-line comments */ }

\"([^\"\\]|\\.)*    { report_error(SYNTAX_ERROR, "Unterminated string literal", prev_valid_line); return UNKNOWN; }
\'([^\'\\]|\\.)*    { report_error(SYNTAX_ERROR, "Unterminated character literal", prev_valid_line); return UNKNOWN; }

. {
    char buf[64];
    snprintf(buf, sizeof(buf), "Unrecognized character: '%c'", yytext[0]);
    report_error(SYNTAX_ERROR, buf, prev_valid_line);
    return UNKNOWN;
}

%%
