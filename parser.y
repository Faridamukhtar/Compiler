%{
#include <stdio.h>
#include <stdlib.h>
#include "lex.yy.h"  

extern int yylex();
extern int yyparse();

void yyerror(const char *s);
%}

/* Define tokens */
%token IF THEN ELSE REPEAT UNTIL WHILE FOR SWITCH CASE DEFAULT FUNCTION RETURN CONST
%token AND OR NOT
%token EQ NEQ GTE LTE GT LT
%token PLUS MINUS MUL DIV EXP
%token ASSIGN SEMI COLON COMMA LPAREN RPAREN LBRACE RBRACE
%token TYPE FLOAT INT BOOLEAN IDENTIFIER
%token UNKNOWN

%%

program:
    statement_list
    ;

statement_list:
    statement_list statement
    | /* empty */
    ;

statement:
    declaration SEMI
    | assignment SEMI
    | if_stmt
    | while_stmt
    | for_stmt
    | switch_stmt
    | return_stmt SEMI
    | repeat_stmt
    | function_decl
    | const_decl SEMI
    ;

declaration:
    TYPE IDENTIFIER
    ;

assignment:
    IDENTIFIER ASSIGN expression
    ;

if_stmt:
    IF expression THEN statement_list else_part
    ;

else_part:
    ELSE statement_list
    | /* empty */
    ;

while_stmt:
    WHILE LPAREN expression RPAREN statement
    ;

for_stmt:
    FOR LPAREN declaration SEMI expression SEMI assignment RPAREN statement
    ;

switch_stmt:
    SWITCH LPAREN expression RPAREN LBRACE case_list default_case RBRACE
    ;

case_list:
    case_list CASE expression COLON statement_list
    | /* empty */
    ;

default_case:
    DEFAULT COLON statement_list
    | /* empty */
    ;

return_stmt:
    RETURN expression
    | RETURN /* for empty return */
    ;

expression:
    INT
    | FLOAT
    | BOOLEAN
    | IDENTIFIER
    | expression PLUS expression
    | expression MINUS expression
    | expression MUL expression
    | expression DIV expression
    | expression EXP expression
    | LPAREN expression RPAREN
    | NOT expression
    | expression AND expression
    | expression OR expression
    | expression EQ expression
    | expression NEQ expression
    | expression GTE expression
    | expression LTE expression
    | expression GT expression
    | expression LT expression
    ;

repeat_stmt:
    REPEAT statement_list UNTIL LPAREN expression RPAREN SEMI
    ;

function_decl:
    FUNCTION TYPE IDENTIFIER LPAREN params RPAREN LBRACE statement_list RBRACE
    ;

params:
    /* empty */
    | param_list
    ;

param_list:
    param_list COMMA param
    | param
    ;

param:
    TYPE IDENTIFIER
    ;

const_decl:
    CONST TYPE IDENTIFIER ASSIGN expression
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
}

int main() {
    printf("Starting parser...\n");
    FILE *input = fopen("input.txt", "r");
    if (input) {
        yyin = input;  // Set the input file for the lexer
        int result = yyparse();
        if (result == 0) {
            printf("Parsing successful!\n");
        } else {
            printf("Parsing failed!\n");
        }
        fclose(input);
    } else {
        printf("Failed to open input file.\n");
    }
    return 0;
}