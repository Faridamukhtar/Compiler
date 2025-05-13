%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "lex.yy.h"  
#include "symbol_table.h"
#include "helpers.h"
#include "parameter.h"
#include "error_handler.h"

extern int yylex();
extern int yyparse();
extern int prev_valid_line;

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
    TYPE identifier_list  {
        int count = 0;
        char** result = split($2, ",", &count);
        if (result) {
            Value myvalue;
            for (int i = 0; i < count; i++) {
                if (isSymbolDeclaredInCurrentScope(result[i])) {
                    yyerror("Redeclared identifier");
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
            yyerror("Redeclared identifier");
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' already declared in this scope.\n", @2.first_line, $2);
        } else {
            addSymbol($2, $1, true , $4.value, false, false, NULL);
        }
    }
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
    IDENTIFIER INC {
        if (!lookupSymbol($1)) {
            yyerror("Undeclared identifier");
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @1.first_line, $1);
            // YYABORT;
        }
        handlePrefixInc($1);
    }
    | IDENTIFIER DEC {
        if (!lookupSymbol($1)) {
            yyerror("Undeclared identifier");
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @1.first_line, $1);
            // YYABORT;
        }
        handlePostfixDec($1);
    }
    | INC IDENTIFIER {
        if (!lookupSymbol($2)) {
            yyerror("Undeclared identifier");
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @2.first_line, $2);
            // YYABORT;
        }
        handlePrefixInc($2);
    }
    | DEC IDENTIFIER {
        if (!lookupSymbol($2)) {
            yyerror("Undeclared identifier");
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @2.first_line, $2);
            // YYABORT;
        }
        handlePostfixDec($2);
    }
    | IDENTIFIER ASSIGN expression {
        if (!lookupSymbol($1)) {
            yyerror("Undeclared identifier");
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @1.first_line, $1);
            // YYABORT;
        }
        updateSymbolValue($1, $3.value);
    }
    | IDENTIFIER ASSIGN error {
        report_error(SYNTAX_ERROR, "Expected an expression", prev_valid_line);
        yyerrok;
    }
    ;

if_stmt:
    IF LPAREN expression RPAREN LBRACE {enterScope();} statement_list RBRACE  {exitScope();} else_part
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
    ELSE LBRACE {enterScope();} statement_list RBRACE {exitScope();}
    | ELSE if_stmt
    | ELSE error {
        report_error(SYNTAX_ERROR, "Malformed else statement", prev_valid_line);
        yyerrok;
    }
    | /* empty */
    ;

while_stmt:
    WHILE LPAREN expression RPAREN LBRACE {enterScope();} statement_list RBRACE {exitScope();}
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
    FOR LPAREN for_stmt_declaration SEMI expression SEMI assignment RPAREN LBRACE {enterScope();} statement_list RBRACE {exitScope();}
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
    SWITCH LPAREN IDENTIFIER RPAREN LBRACE {enterScope();} case_list default_case RBRACE {exitScope();}
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
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", @1.first_line, $1);
            // YYABORT;
        }
        if (!entry->isInitialized) {
            fprintf(stderr, "Semantic Warning (line %d): Variable '%s' used before initialization.\n", @1.first_line, $1);
        }
        $$ = (expr){.type = entry->type, .value = entry->value};
    }
    ;

repeat_stmt:
    REPEAT LBRACE {enterScope();} statement_list RBRACE {exitScope();} UNTIL LPAREN expression RPAREN SEMI
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
    FUNCTION TYPE IDENTIFIER LPAREN params RPAREN LBRACE {enterScope();} statement_list RBRACE {
        exitScope();
        Value myValue;
        addSymbol($3, $2, true, myValue, false, true, $5);
    }
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
    
}

int main() {
    printf("Starting parser...\n");
    initSymbolTable();
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
        } else {
            printf("Parsing successful!\n");
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