%{
#include <stdio.h>
#include <stdlib.h>
#include "lex.yy.h"  

extern int yylex();
extern int yyparse();

void yyerror(const char *s);
%}

/* Define tokens */
%token IF ELSE REPEAT UNTIL WHILE FOR SWITCH CASE DEFAULT FUNCTION RETURN CONST BREAK CONTINUE
%token AND OR NOT
%token EQ NEQ GTE LTE GT LT
%token PLUS MINUS MUL DIV EXP MOD
%token ASSIGN SEMI COLON COMMA LPAREN RPAREN LBRACE RBRACE
%token TYPE FLOAT INT BOOLEAN IDENTIFIER STRING CHAR
%token UNKNOWN

/* Define operator precedence */
%left OR
%left AND
%left EQ NEQ
%left LT GT LTE GTE
%left PLUS MINUS
%left MUL DIV MOD
%right EXP
%right NOT
%nonassoc UMINUS
%right INC DEC

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
    | function_call SEMI
    | CONTINUE SEMI
    | BREAK SEMI
    ;

declaration:
    TYPE identifier_list
    | TYPE IDENTIFIER ASSIGN expression
    ;

identifier_list:
    IDENTIFIER
    | identifier_list COMMA IDENTIFIER
    ;

assignment:
    | IDENTIFIER INC
    | IDENTIFIER DEC
    | INC IDENTIFIER
    | DEC IDENTIFIER
    | IDENTIFIER ASSIGN expression
    ;

if_stmt:
    IF LPAREN expression RPAREN LBRACE statement_list RBRACE else_part
    ;

else_part:
    ELSE LBRACE statement_list RBRACE
    | ELSE if_stmt
    | /* empty */
    ;

while_stmt:
    WHILE LPAREN expression RPAREN LBRACE statement_list RBRACE
    ;

for_stmt:
    FOR LPAREN for_stmt_declaration SEMI expression SEMI assignment RPAREN LBRACE statement_list RBRACE
    ;

for_stmt_declaration:
    TYPE IDENTIFIER ASSIGN expression
    | TYPE IDENTIFIER
    | IDENTIFIER ASSIGN expression
    ;

CONSTANT_VAL:
    INT
    | FLOAT
    | BOOLEAN
    | IDENTIFIER
    ;

switch_stmt:
    SWITCH LPAREN IDENTIFIER RPAREN LBRACE case_list default_case RBRACE
    ;

case_list:
    case_list CASE CONSTANT_VAL COLON statement_list
    | /* empty */
    ;

default_case:
    DEFAULT COLON statement_list
    | /* empty */
    ;

return_stmt:
    RETURN expression
    | RETURN
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
    | additive_expr MOD multiplicative_expr
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
    | STRING
    | CHAR
    | function_call
    ;

repeat_stmt:
    REPEAT LBRACE statement_list RBRACE UNTIL LPAREN expression RPAREN SEMI
    ;

function_decl:
    FUNCTION TYPE IDENTIFIER LPAREN params RPAREN LBRACE statement_list RBRACE
    ;

function_call:
    IDENTIFIER LPAREN argument_list RPAREN
    | IDENTIFIER LPAREN RPAREN
    ;

argument_list:
    argument_list COMMA expression
    | expression
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
        yyin = input;
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