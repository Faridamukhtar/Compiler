%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "lex.yy.h"  
#include "symbol_table.h"

Scope *currentScope = NULL;
extern int yylex();
extern int yyparse();

void yyerror(const char *s);
%}

%code requires {
    #include "symbol_table.h"
}

%union {
    int i;
    char c;
    float f;
    char *s;
    char *Dtype;
    SymbolTableEntry *symbolTableEntry;
}


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
    ;

BLOCK:
    LBRACE {
        enterScope();  // Enter a new scope
    }
    statement_list RBRACE {
        exitScope();   // Exit the current scope
    }
    {
        printf("Block parsed\n");
    }
    ;

declaration:
    TYPE identifier_list {
        // TODO: Add each identifier in identifier_list to symbol table with $1 as type
    }
    | TYPE IDENTIFIER ASSIGN expression {
        // TODO: Add $2 to symbol table with $1 as type, mark initialized with $4 as value
    }
    ;

identifier_list:
    IDENTIFIER
    | identifier_list COMMA IDENTIFIER
    ;

assignment:
    IDENTIFIER INC {
        // TODO: Lookup $1 and increment value (prefix)
    }
    | IDENTIFIER DEC {
        // TODO: Lookup $1 and decrement value (prefix)
    }
    | INC IDENTIFIER {
        // TODO: Lookup $2 and increment value (prefix)
    }
    | DEC IDENTIFIER {
        // TODO: Lookup $2 and decrement value (prefix)
    }
    | IDENTIFIER ASSIGN expression {
        // TODO: Update $1 in symbol table with $3 as new value
    }
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
    TYPE IDENTIFIER ASSIGN expression {
        // TODO: Add $2 to symbol table with $1 as type and initialize with $4
    }
    | TYPE IDENTIFIER {
        // TODO: Add $2 to symbol table with $1 as type
    }
    | IDENTIFIER ASSIGN expression {
        // TODO: Update $1 in symbol table with $3
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
    FUNCTION TYPE IDENTIFIER LPAREN params RPAREN LBRACE statement_list RBRACE {
        // TODO: Add function $3 to symbol table with return type $2
        // TODO: Push new scope and register parameters
        // TODO: Pop scope after function body
    }
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
    TYPE IDENTIFIER {
        // TODO: Add parameter $2 with type $1 to current function scope
    }
    ;

const_decl:
    CONST TYPE IDENTIFIER ASSIGN expression {
        // TODO: Add constant $3 to symbol table with type $2 and value $5
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
}

int main() {
    printf("Starting parser...\n");
    enterScope();
    FILE *input = fopen("test/input.txt", "r");
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
    clearSymbolTables(currentScope);
    return 0;
}
