%{
#include <stdio.h>
#include "parser.tab.h" 
#include "error_handler.h"

extern int yylineno;
int last_valid_line = 1;
int prev_valid_line = 1;
%}

%option yylineno noyywrap

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
"{"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return LBRACE; }
"}"             { prev_valid_line = last_valid_line; last_valid_line = yylineno; return RBRACE; }

{TYPE}          { prev_valid_line = last_valid_line; last_valid_line = yylineno; return TYPE; }
{FLOAT}         { prev_valid_line = last_valid_line; last_valid_line = yylineno; return FLOAT; }
{INT}           { prev_valid_line = last_valid_line; last_valid_line = yylineno; return INT; }
{BOOL}          { prev_valid_line = last_valid_line; last_valid_line = yylineno; return BOOLEAN; }
{STRING}        { prev_valid_line = last_valid_line; last_valid_line = yylineno; return STRING; }
{CHAR}          { prev_valid_line = last_valid_line; last_valid_line = yylineno; return CHAR; }
{ID}            { prev_valid_line = last_valid_line; last_valid_line = yylineno; return IDENTIFIER; }

[ \t\r]+        { /* skip whitespace */ }
\n              { /* let yylineno increment automatically */ }

\/\/.*          { /* skip single-line comments */ }
\/\*[^*]*\*+([^/*][^*]*\*+)*\/ { /* skip multi-line comments */ }

\"([^\"\\]|\\.)*    { report_error(SYNTAX_ERROR, "Unterminated string literal", yylineno); return UNKNOWN; }
\'([^\'\\]|\\.)*    { report_error(SYNTAX_ERROR, "Unterminated character literal", yylineno); return UNKNOWN; }

. {
    char buf[64];
    snprintf(buf, sizeof(buf), "Unrecognized character: '%c'", yytext[0]);
    report_error(SYNTAX_ERROR, buf, yylineno);
    return UNKNOWN;
}

%%
