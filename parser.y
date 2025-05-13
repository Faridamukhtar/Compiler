%{
#include <stdio.h>
#include <stdlib.h>
#include "lex.yy.h"  
#include "error_handler.h"

extern int yylex();
extern int yyparse();
extern int prev_valid_line;

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
    | LBRACE statement_list RBRACE
    | declaration error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    | assignment error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    | return_stmt error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    | const_decl error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    | function_call error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    | CONTINUE error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    | BREAK error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    ;

declaration:
    TYPE identifier_list
    | TYPE IDENTIFIER ASSIGN expression
    | TYPE error {
        report_error(SYNTAX_ERROR, "Expected identifier after type", prev_valid_line);
        yyerrok;
    }
    | TYPE IDENTIFIER ASSIGN error {
        report_error(SYNTAX_ERROR, "Expected expression after assignment", prev_valid_line);
        yyerrok;
    }
    ;

identifier_list:
    IDENTIFIER
    | identifier_list COMMA IDENTIFIER
    | identifier_list COMMA error {
        report_error(SYNTAX_ERROR, "Expected an identifier", prev_valid_line);
        yyerrok;
    } 
    ;

assignment:
    IDENTIFIER INC
    | IDENTIFIER DEC
    | INC IDENTIFIER
    | DEC IDENTIFIER
    | IDENTIFIER ASSIGN expression
    | IDENTIFIER ASSIGN error {
        report_error(SYNTAX_ERROR, "Expected an expression", prev_valid_line);
        yyerrok;
    }
    ;

if_stmt:
    IF LPAREN expression RPAREN LBRACE statement_list RBRACE else_part
    | IF error {
        report_error(SYNTAX_ERROR, "Expected '(' in if condition", prev_valid_line);
        yyerrok;
    }
    | IF LPAREN expression error {
        report_error(SYNTAX_ERROR, "Expected ')' in if condition", prev_valid_line);
        yyerrok;
    }
    | IF LPAREN expression RPAREN error {
        report_error(SYNTAX_ERROR, "Malformed if statement", prev_valid_line);
        yyerrok;
    }
    ;

else_part:
    ELSE LBRACE statement_list RBRACE
    | ELSE if_stmt
    | ELSE error {
        report_error(SYNTAX_ERROR, "Malformed else statement", prev_valid_line);
        yyerrok;
    }
    | /* empty */
    ;

while_stmt:
    WHILE LPAREN expression RPAREN LBRACE statement_list RBRACE
    | WHILE error {
        report_error(SYNTAX_ERROR, "Expected '(' in while condition", prev_valid_line);
        yyerrok;
    }
    | WHILE LPAREN expression error {
        report_error(SYNTAX_ERROR, "Expected ')' in while condition", prev_valid_line);
        yyerrok;
    }
    | WHILE LPAREN expression RPAREN error {
        report_error(SYNTAX_ERROR, "Malformed while statement", prev_valid_line);
        yyerrok;
    }
    | WHILE LPAREN error {
        report_error(SYNTAX_ERROR, "Malformed while loop header", prev_valid_line);
        yyerrok;
    }
    ;

for_stmt:
    FOR LPAREN for_stmt_declaration SEMI expression SEMI assignment RPAREN LBRACE statement_list RBRACE
    | FOR error {
        report_error(SYNTAX_ERROR, "Expected '(' in for loop", prev_valid_line);
        yyerrok;
    }
    | FOR LPAREN for_stmt_declaration error {
        report_error(SYNTAX_ERROR, "Expected ';' in for loop", prev_valid_line);
        yyerrok;
    }
    | FOR LPAREN for_stmt_declaration SEMI expression SEMI assignment error {
        report_error(SYNTAX_ERROR, "Expected ')' in for loop", prev_valid_line);
        yyerrok;
    }
    | FOR LPAREN for_stmt_declaration SEMI expression SEMI assignment RPAREN error {
        report_error(SYNTAX_ERROR, "Malformed for statement", prev_valid_line);
        yyerrok;
    }
    ;

for_stmt_declaration:
    TYPE IDENTIFIER ASSIGN expression
    | TYPE IDENTIFIER
    | IDENTIFIER ASSIGN expression
    | TYPE error {
        report_error(SYNTAX_ERROR, "Expected identifier after type", prev_valid_line);
        yyerrok;
    }
    | TYPE IDENTIFIER ASSIGN error {
        report_error(SYNTAX_ERROR, "Expected expression after assignment", prev_valid_line);
        yyerrok;
    }
    | IDENTIFIER ASSIGN error {
        report_error(SYNTAX_ERROR, "Expected expression after assignment", prev_valid_line);
        yyerrok;
    }
    ;

CONSTANT_VAL:
    INT
    | FLOAT
    | BOOLEAN
    | IDENTIFIER
    ;

switch_stmt:
    SWITCH LPAREN IDENTIFIER RPAREN LBRACE case_list default_case RBRACE
    | SWITCH error {
        report_error(SYNTAX_ERROR, "Expected '(' in switch statement", prev_valid_line);
        yyerrok;
    }
    | SWITCH LPAREN IDENTIFIER error {
        report_error(SYNTAX_ERROR, "Expected ')' in switch statement", prev_valid_line);
        yyerrok;
    }
    | SWITCH LPAREN IDENTIFIER RPAREN error {
        report_error(SYNTAX_ERROR, "Malformed switch statement", prev_valid_line);
        yyerrok;
    }
    ;

case_list:
    case_list CASE CONSTANT_VAL COLON statement_list
    | case_list CASE CONSTANT_VAL error {
        report_error(SYNTAX_ERROR, "Expected ':'", prev_valid_line);
        yyerrok;
    }
    | case_list CASE error {
        report_error(SYNTAX_ERROR, "Invalid constant in switch case", prev_valid_line);
        yyerrok;
    }
    | /* empty */
    ;

default_case:
    DEFAULT COLON statement_list
    | DEFAULT error {
        report_error(SYNTAX_ERROR, "Expected ':'", prev_valid_line);
        yyerrok;
    }
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
    | REPEAT error {
        report_error(SYNTAX_ERROR, "Expected '(' in repeat statement", prev_valid_line);
        yyerrok;
    }
    /* | REPEAT LBRACE statement_list error {
        report_error(SYNTAX_ERROR, "Expected ')' in repeat statement", prev_valid_line);
        yyerrok;
    } */
    | REPEAT LBRACE statement_list RBRACE UNTIL error {
        report_error(SYNTAX_ERROR, "Expected expression in repeat statement", prev_valid_line);
        yyerrok;
    }
    | REPEAT LBRACE statement_list RBRACE UNTIL LPAREN expression RPAREN error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    ;

function_decl:
    FUNCTION TYPE IDENTIFIER LPAREN params RPAREN LBRACE statement_list RBRACE
    /* | FUNCTION error {
        report_error(SYNTAX_ERROR, "Type is missing", prev_valid_line);
        yyerrok;
    }
    | FUNCTION TYPE IDENTIFIER error {
        report_error(SYNTAX_ERROR, "Expected '(' in function declaration", prev_valid_line);
        yyerrok;
    }
    | FUNCTION TYPE IDENTIFIER LPAREN params error {
        report_error(SYNTAX_ERROR, "Expected ')' in function declaration", prev_valid_line);
        yyerrok;
    } */
    ;

function_call:
    IDENTIFIER LPAREN argument_list RPAREN
    | IDENTIFIER LPAREN RPAREN
    /* | IDENTIFIER error {
        report_error(SYNTAX_ERROR, "Expected '(' in function call", prev_valid_line);
        yyerrok;
    } */
    | IDENTIFIER LPAREN error {
        report_error(SYNTAX_ERROR, "Expected ')' in function call", prev_valid_line);
        yyerrok;
    }
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
    
}

int main() {
    printf("Starting parser...\n");
    FILE *input = fopen("test/input.txt", "r");
    if (input) {
        yyin = input;
        yylineno = 1;
        int result = yyparse();
        fclose(input);
        printf("\n=== Parsing Finished ===\n");
        print_all_errors();  

        if (get_error_count() > 0) {
            printf("Parsing failed with errors.\n");
            return 1;
        } else {
            printf("Parsing successful!\n");
            return 0;
        }
    } else {
        printf("Failed to open input file.\n");
    }
    return 0;
}