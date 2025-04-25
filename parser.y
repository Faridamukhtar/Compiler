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

/* Define operator precedence */
%left OR
%left AND
%left EQ NEQ
%left LT GT LTE GTE
%left PLUS MINUS
%left MUL DIV
%right EXP
%right NOT
%nonassoc UMINUS

%%

/* Grammar Rules */

program:
    statement_list
    ;

statement_list:
    statement statement_list
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
    | TYPE IDENTIFIER ASSIGN expression
    ;

assignment:
    IDENTIFIER ASSIGN expression
    ;

if_stmt:
    IF LPAREN expression RPAREN LBRACE statement RBRACE else_part
    ;

else_part:
    ELSE LBRACE statement RBRACE
    | ELSE if_stmt  /* Nested if-else */
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
    logical_expr
    ;

logical_expr:
    logical_expr OR logical_term
    | logical_term
    ;

logical_term:
    logical_term AND equality_expr
    | equality_expr
    ;

equality_expr:
    equality_expr EQ relational_expr
    | equality_expr NEQ relational_expr
    | relational_expr
    ;

relational_expr:
    relational_expr LT additive_expr
    | relational_expr GT additive_expr
    | relational_expr LTE additive_expr
    | relational_expr GTE additive_expr
    | additive_expr
    ;

additive_expr:
    additive_expr PLUS multiplicative_expr
    | additive_expr MINUS multiplicative_expr
    | multiplicative_expr
    ;

multiplicative_expr:
    multiplicative_expr MUL exponent_expr
    | multiplicative_expr DIV exponent_expr
    | exponent_expr
    ;

exponent_expr:
    exponent_expr EXP unary_expr
    | unary_expr
    ;

unary_expr:
    NOT unary_expr
    | MINUS unary_expr
    | primary_expr
    ;

primary_expr:
    IDENTIFIER
    | INT
    | FLOAT
    | BOOLEAN
    | LPAREN expression RPAREN
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