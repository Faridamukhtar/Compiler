%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "lex.yy.h"
#include "symbol_table.h"
#include "helpers.h"
#include "parameter.h"

extern int yylex();
extern int yyparse();

void yyerror(const char *s);
%}

%code requires {
    #include "symbol_table.h"
    #include "helpers.h"
    #include "parameter.h"
}

/* Enable location tracking */
%define api.location.type {struct YYLTYPE { int first_line; int first_column; int last_line; int last_column; }}
%locations

%union {
    int i;
    char c;
    float f;
    char *s;
    expr expr;
    Parameter *param_list;
}

/* Define tokens */
%token IF ELSE REPEAT UNTIL WHILE FOR SWITCH CASE DEFAULT FUNCTION RETURN CONST BREAK CONTINUE
%token AND OR NOT
%token EQ NEQ GTE LTE GT LT
%token PLUS MINUS MUL DIV EXP MOD
%token ASSIGN SEMI COLON COMMA LPAREN RPAREN LBRACE RBRACE
%token <i> INT
%token <f> FLOAT
%token <c> CHAR
%token <i> BOOLEAN
%token <s> IDENTIFIER TYPE STRING
%token UNKNOWN

%type <expr> expression logical_expr logical_term equality_expr relational_expr additive_expr multiplicative_expr exponent_expr unary_expr primary_expr
%type <param_list> params param_list param
%type <s> identifier_list

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

declaration: 
    TYPE identifier_list  {
        int count = 0;
        char** result = split($2, ",", &count);
        if (result) {
            Value myvalue;
            for (int i = 0; i < count; i++) {
                if (isSymbolDeclaredInCurrentScope(result[i])) {
                    fprintf(stderr, "Semantic Error (line %d): Variable '%s' already declared in this scope.\n", @2.first_line, result[i]);
                } else {
                    addSymbol(result[i], $1, false, myvalue, false, false, NULL);
                }
            }
            free_split_result(result, count);
        } else {
            printf("Error splitting string\n");
        }
    }
    | TYPE IDENTIFIER ASSIGN expression {
        if (isSymbolDeclaredInCurrentScope($2)) {
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' already declared in this scope.\n", @2.first_line, $2);
        } else {
            addSymbol($2, $1, true , $4.value, false, false, NULL);
        }
    }
    ;

identifier_list:
    IDENTIFIER
    | identifier_list COMMA IDENTIFIER
    ;

assignment: 
    IDENTIFIER INC {
        if (!lookupSymbol($1)) {
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @1.first_line, $1);
            YYABORT;
        }
        handlePrefixInc($1);
    }
    | IDENTIFIER DEC {
        if (!lookupSymbol($1)) {
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @1.first_line, $1);
            YYABORT;
        }
        handlePostfixDec($1);
    }
    | INC IDENTIFIER {
        if (!lookupSymbol($2)) {
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @2.first_line, $2);
            YYABORT;
        }
        handlePrefixInc($2);
    }
    | DEC IDENTIFIER {
        if (!lookupSymbol($2)) {
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @2.first_line, $2);
            YYABORT;
        }
        handlePostfixDec($2);
    }
    | IDENTIFIER ASSIGN expression 
    {
        if (!lookupSymbol($1)) {
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @1.first_line, $1);
            YYABORT;
        }
        updateSymbolValue($1, $3.value);
    }
    ;

if_stmt:
    IF LPAREN expression RPAREN LBRACE {enterScope();} statement_list RBRACE  {exitScope();} else_part
    ;

else_part:
    ELSE LBRACE {enterScope();} statement_list RBRACE {exitScope();}
    | ELSE if_stmt
    | /* empty */
    ;

while_stmt:
    WHILE LPAREN expression RPAREN LBRACE {enterScope();} statement_list RBRACE {exitScope();}
    ;

for_stmt:
    FOR LPAREN for_stmt_declaration SEMI expression SEMI assignment RPAREN LBRACE {enterScope();} statement_list RBRACE {exitScope();}
    ;

for_stmt_declaration:
    TYPE IDENTIFIER ASSIGN expression {
        Value myValue = $4.value;
        addSymbol($2, $1, true, myValue, true, false, NULL);
    }
    | TYPE IDENTIFIER {
        Value myValue;
        addSymbol($2, $1, false, myValue, false, false, NULL);
        }
    | IDENTIFIER ASSIGN expression {
        updateSymbolValue($1, $3.value);
    }
    ;

CONSTANT_VAL:
    INT 
    | FLOAT
    | BOOLEAN
    | IDENTIFIER 
    ;

switch_stmt:
    SWITCH LPAREN IDENTIFIER RPAREN LBRACE {enterScope();} case_list default_case RBRACE {exitScope();}
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
    logical_expr OR logical_term {
        $$ = $1;
    }
    | logical_term {
        $$ = $1;
    }
    ;

logical_term:
    logical_term AND equality_expr {
        $$ = $1;
    }
    | equality_expr {
        $$ = $1;
    }
    ;

equality_expr:
    equality_expr EQ relational_expr {
        $$ = $1;
    }
    | equality_expr NEQ relational_expr {
        $$ = $1;
    }
    | relational_expr {
        $$ = $1;
    }
    ;

relational_expr:
    relational_expr LT additive_expr {
        $$ = $1;
    }
    | relational_expr GT additive_expr {
        $$ = $1;
    }
    | relational_expr LTE additive_expr {
        $$ = $1;
    }
    | relational_expr GTE additive_expr {
        $$ = $1;
    }
    | additive_expr {
        $$ = $1;
    }
    ;

additive_expr:
    additive_expr PLUS multiplicative_expr {
        $$ = $1;
    }
    | additive_expr MINUS multiplicative_expr {
        $$ = $1;
    }
    | multiplicative_expr {
        $$ = $1;
    }
    ;

multiplicative_expr:
    multiplicative_expr MUL exponent_expr {
        $$ = $1;
    }
    | multiplicative_expr DIV exponent_expr {
        $$ = $1;
    }
    | exponent_expr {
        $$ = $1;
    }
    ;

exponent_expr:
    exponent_expr EXP unary_expr {
        $$ = $1;
    }
    | unary_expr {
        $$ = $1;
    }
    ;

unary_expr:
    MINUS unary_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true};
    }
    | NOT unary_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true};
    }
    | primary_expr { $$ = $1; }
    ;

primary_expr:
    INT {
        Value val;
        val.iVal = $1;
        $$ = (expr){.type = INT_TYPE, .value = val};
    }
    | FLOAT {
        Value val;
        val.fVal = $1;
        $$ = (expr){.type = FLOAT_TYPE, .value = val};
    }
    | CHAR {
        Value val;
        val.cVal = $1;
        $$ = (expr){.type = CHAR_TYPE, .value = val};
    }
    | BOOLEAN {
        Value val;
        val.bVal = ($1 != 0);
        $$ = (expr){.type = BOOL_TYPE, .value = val};
    }
    | STRING {
        Value val;
        val.sVal = strdup($1); 
        $$ = (expr){.type = STRING_TYPE, .value = val};
    }
    | LPAREN expression RPAREN {
        $$ = $2; 
    }
    | function_call {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true};
    }
    | IDENTIFIER {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry) {
            yyerror("Undeclared identifier");
            YYABORT;
        }
        $$ = (expr){.type = entry->type, .value = entry->value};
    }
    ;

repeat_stmt:
    REPEAT LBRACE {enterScope();} statement_list RBRACE {exitScope();} UNTIL LPAREN expression RPAREN SEMI
    ;

function_decl:
    FUNCTION TYPE IDENTIFIER LPAREN params RPAREN LBRACE {enterScope();} statement_list RBRACE {
        exitScope();
        Value myValue;
        addSymbol($3, $2, true, myValue, false, true, $5);
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
    | param_list { $$ = $1; }
    ;

param_list:
    param_list COMMA param {
        $$ = addParameter($1, $3);  // Add the parameter to the list
    }
    | param {
        $$ = $1;
    }
    ;

param:
    TYPE IDENTIFIER {
        Value myValue;
        addSymbol($2, $1, false, myValue, true, false, NULL);
        $$ = createParameter($2, $1);  // Create a new parameter
    }
    ;

const_decl:
    CONST TYPE IDENTIFIER ASSIGN expression {
        Value myValue = $5.value;
        addSymbol($3, $2, true, myValue, true, false, NULL);
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Parse error at line %d: %s\n", yylloc.first_line, s);
}

int main() {
    printf("Starting parser...\n");
    initSymbolTable();
    FILE *input = fopen("test/input.txt", "r");
    if (input) {
        yyin = input;
        int result = yyparse();
        if (result == 0) {
            printf("Parsing successful!\n");
        } else {
            printf("Parsing failed!\n");
        }
        FILE *output = fopen("symbol_table.txt", "w");
        if (output) {
            writeSymbolTableOfAllScopesToFile(output);
            fclose(output);
        } else {
            printf("Failed to open symbol_table.txt for writing.\n");
        }
        // reportUnusedVariables();
        // reportUninitializedVariables();
        fclose(input);
        clearSymbolTables(currentScope);
    } else {
        printf("Failed to open input file.\n");
    }
    return 0;
}