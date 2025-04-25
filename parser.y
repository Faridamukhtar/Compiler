%{
#include <stdio.h>
#include <stdlib.h>
#include "lex.yy.h"  

// Function prototypes
void yyerror(const char *s);
int yylex(void);
%}

/* Token declarations for Flex lexer */
%token IF THEN ELSE REPEAT UNTIL WHILE FOR SWITCH CASE DEFAULT FUNCTION RETURN CONST
%token AND OR NOT
%token EQ NEQ GTE LTE GT LT
%token PLUS MINUS MUL DIV EXP
%token ASSIGN SEMI COLON COMMA LPAREN RPAREN LBRACE RBRACE
%token TYPE
%token FLOAT INT BOOLEAN IDENTIFIER
%token UNKNOWN

/* Define operator precedence (optional but useful) */
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

program:
    statement_list
    ;

statement_list:
    statement statement_list { printf("Parsed a statement.\n"); }
    | /* empty */ { printf("End of statement list.\n"); }
    ;

statement:
    declaration SEMI { printf("Declaration statement parsed.\n"); }
    | assignment SEMI { printf("Assignment statement parsed.\n"); }
    | if_stmt { printf("If statement parsed.\n"); }
    | while_stmt { printf("While statement parsed.\n"); }
    | return_stmt SEMI { printf("Return statement parsed.\n"); }
    ;

declaration:
    TYPE IDENTIFIER { printf("Declaration: %s\n", yytext); }
    ;

assignment:
    IDENTIFIER ASSIGN expression { printf("Assignment: %s = %d\n", yytext, $3); }
    ;

if_stmt:
    IF expression THEN statement_list ELSE statement_list { printf("If statement parsed.\n"); }
    ;

while_stmt:
    WHILE expression statement_list { printf("While statement parsed.\n"); }
    ;

return_stmt:
    RETURN expression { printf("Return statement parsed.\n"); }
    ;

expression:
    IDENTIFIER { printf("Expression: %s\n", yytext); }
    | INT { printf("Integer expression: %d\n", atoi(yytext)); }
    | FLOAT { printf("Float expression: %f\n", atof(yytext)); }
    | BOOLEAN { printf("Boolean expression: %s\n", yytext); }
    | expression PLUS expression { printf("Plus expression\n"); }
    | expression MINUS expression { printf("Minus expression\n"); }
    | expression MUL expression { printf("Mul expression\n"); }
    | expression DIV expression { printf("Div expression\n"); }
    | LPAREN expression RPAREN { printf("Parenthesized expression\n"); }
    | MINUS expression %prec UMINUS { printf("Unary minus expression\n"); }
    | NOT expression { printf("Not expression\n"); }
    ;

%%

/* Error handling function */
void yyerror(const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
}

/* Main function to call parser */
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
