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

SymbolTableEntry* currentFunction = NULL;
ValueType currentFunctionReturnType = VOID_TYPE;

void yyerror(const char *s);
%}


/* Enable location tracking */
%define api.location.type {struct YYLTYPE { int first_line; int first_column; int last_line; int last_column; }}
%locations

%code requires {
    #include "symbol_table.h"
    #include "helpers.h"
    #include "parameter.h"
}

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

%type <expr> expression logical_expr logical_term equality_expr relational_expr additive_expr multiplicative_expr exponent_expr unary_expr primary_expr function_call
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
    | LBRACE {enterScope();}  statement_list RBRACE {exitScope();}
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
                    report_error(SEMANTIC_ERROR, "Variable Redeclaration", prev_valid_line);
                    fprintf(stderr, "Semantic Error (line %d): Variable '%s' already declared in this scope.\n", prev_valid_line, result[i]);
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
            report_error(SEMANTIC_ERROR, "Variable Redeclaration", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' already declared in this scope.\n", prev_valid_line, $2);
        } else {
            ValueType declaredType = mapStringToValueType($1);
            if (!areTypesCompatible(declaredType, $4.type)) {
                report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
                fprintf(stderr, "Semantic Error (line %d): Incompatible type assignment to variable '%s'.\n", prev_valid_line, $2);
            } else {
                addSymbol($2, $1, true , $4.value, false, false, NULL);
            }
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
    {$$ = $1;}
    | identifier_list COMMA IDENTIFIER
    {
        $$ = concat_with_comma($1,$3);
    }
    | identifier_list COMMA error {
        report_error(SYNTAX_ERROR, "Expected an identifier", prev_valid_line);
        yyerrok;
    } 
    ;

assignment:
    IDENTIFIER INC {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry) {
           report_error(SEMANTIC_ERROR, "Variable Undeclared", prev_valid_line);
           fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", prev_valid_line, $1);
            // YYABORT;
        } 
        else {
            if (!entry->isInitialized) {
                fprintf(stderr, "Semantic Warning (line %d): Variable '%s' used before initialization.\n", prev_valid_line, $1);
            }
            handlePrefixInc($1);
        }
    }
    | IDENTIFIER DEC {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry) {
            report_error(SEMANTIC_ERROR, "Variable Undeclared", prev_valid_line);
           fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", prev_valid_line, $1);
            // YYABORT;
        } 
        else {
            if (!entry->isInitialized) {
                fprintf(stderr, "Semantic Warning (line %d): Variable '%s' used before initialization.\n", prev_valid_line, $1);
            }
            handlePostfixDec($1);
        }
    }
    | INC IDENTIFIER {
        SymbolTableEntry *entry = lookupSymbol($2);
        if (!entry) {
            report_error(SEMANTIC_ERROR, "Variable Undeclared", prev_valid_line);
           fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", prev_valid_line, $2);
            // YYABORT;
        } 
        else {
            if (!entry->isInitialized) {
                fprintf(stderr, "Semantic Warning (line %d): Variable '%s' used before initialization.\n", prev_valid_line, $2);
            }
            handlePrefixInc($2);
        }
    }
    | DEC IDENTIFIER {
        SymbolTableEntry *entry = lookupSymbol($2);
        if (!entry) {
            report_error(SEMANTIC_ERROR, "Variable Undeclared", prev_valid_line);
           fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", prev_valid_line, $2);
            // YYABORT;
        } 
        else {
            if (!entry->isInitialized) {
                fprintf(stderr, "Semantic Warning (line %d): Variable '%s' used before initialization.\n", prev_valid_line, $2);
            }
            handlePostfixDec($2);
        }
    }
    | IDENTIFIER ASSIGN expression {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry) {
            report_error(SEMANTIC_ERROR, "Variable Undeclared", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", prev_valid_line, $1);
        } else {
            if (!areTypesCompatible(entry->type, $3.type)) {
                report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
                fprintf(stderr, "Semantic Error (line %d): Incompatible type assignment to variable '%s'.\n", prev_valid_line, $1);
            }
            else {
                updateSymbolValue($1, $3.value);
            }
        }
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
    RETURN expression {
        if (currentFunctionReturnType == VOID_TYPE) {
            report_error(SEMANTIC_ERROR, "Void Function Return Value", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Void function '%s' should not return a value.\n",
                    prev_valid_line,
                    currentFunction ? currentFunction->identifierName : "unknown");
        } else if (!areTypesCompatible(currentFunctionReturnType, $2.type)) {
            report_error(SEMANTIC_ERROR, "Return Type Mismatch", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Return type mismatch in function '%s'.\n",
                    prev_valid_line,
                    currentFunction ? currentFunction->identifierName : "unknown");
        }
    }
    | RETURN {
        if (currentFunctionReturnType != VOID_TYPE) {
            report_error(SEMANTIC_ERROR, "Missing Return Value", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Function '%s' must return nothing (void).\n",
                    prev_valid_line,
                    currentFunction ? currentFunction->identifierName : "unknown");
        }
    }
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
        if (!areTypesCompatible($1.type, $3.type)) {
            report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Incompatible types in addition.\n", prev_valid_line);
        }
        $$ = $1;
    }
    | additive_expr MINUS multiplicative_expr {
        if (!areTypesCompatible($1.type, $3.type)) {
            report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Incompatible types in subtraction.\n", prev_valid_line);
        }
        $$ = $1;
    }
    | multiplicative_expr {
        $$ = $1;
    }
    ;

multiplicative_expr:
    multiplicative_expr MUL exponent_expr {
        if (!areTypesCompatible($1.type, $3.type)) {
            report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Incompatible types in multiplication.\n", prev_valid_line);
        }
        $$ = $1;
    }
    | multiplicative_expr DIV exponent_expr {
        if (!areTypesCompatible($1.type, $3.type)) {
            report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Incompatible types in division.\n", prev_valid_line);
        }
        $$ = $1;
    }
    | exponent_expr {
        $$ = $1;
    }
    ;

exponent_expr:
    exponent_expr EXP unary_expr {
        if (!areTypesCompatible($1.type, $3.type)) {
            report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Incompatible types in exponentiation.\n", prev_valid_line);
        }
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
        size_t len = strlen($1);
        if (len >= 2) {
            char* cropped = (char*)malloc(len - 1); 
            strncpy(cropped, $1 + 1, len - 2);
            cropped[len - 2] = '\0'; 
            val.sVal = cropped;
        } else {
            val.sVal = strdup(""); 
        }
        $$ = (expr){.type = STRING_TYPE, .value = val};
    }
    | LPAREN expression RPAREN {
        $$ = $2; 
    }
    | function_call { 
        $$ = $1; 
    }
    | IDENTIFIER {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry) {
            report_error(SEMANTIC_ERROR, "Variable Undeclared", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' used before declaration.\n", prev_valid_line, $1);
            // YYABORT;
        }
        else {
            if (!entry->isInitialized  && !entry->isFunction) {
                fprintf(stderr, "Semantic Warning (line %d): Variable '%s' used before initialization.\n", prev_valid_line, $1);
            }
            entry->isUsed = true;
            $$ = (expr){.type = entry->type, .value = entry->value};
        }
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
    FUNCTION TYPE IDENTIFIER LPAREN params RPAREN {
        Value myValue;
        addSymbol($3, $2, true, myValue, false, true, $5); 
        currentFunction = lookupSymbol($3);
        currentFunctionReturnType = mapStringToValueType($2);
        enterScope();
        addParamsToSymbolTable($5);
    } LBRACE statement_list RBRACE {
        exitScope();
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
    IDENTIFIER LPAREN argument_list RPAREN {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry || !entry->isFunction) {
            report_error(SEMANTIC_ERROR, "Invalid Function Call", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Function '%s' is not declared.\n", prev_valid_line, $1);
            $$ = (expr){.type = BOOL_TYPE};  // fallback
        } else {
            entry->isUsed = true;
            $$ = (expr){.type = entry->type, .value = (Value){}};
        }
    }
    | IDENTIFIER LPAREN RPAREN {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry || !entry->isFunction) {
            report_error(SEMANTIC_ERROR, "Invalid Function Call", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Function '%s' is not declared.\n", prev_valid_line, $1);
            $$ = (expr){.type = BOOL_TYPE};
        } else {
            entry->isUsed = true;
            $$ = (expr){.type = entry->type, .value = (Value){}};
        }
    }
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
    /* empty */ { $$ = NULL; }
    | param_list { $$ = $1; }
    ;

param_list:
    param_list COMMA param {
        $$ = addParameter($1, $3);
    }
    | param {
        $$ = $1;
    }
    ;

param:
    TYPE IDENTIFIER {
        $$ = createParameter($2, $1);
    }
    ;

const_decl:
    CONST TYPE IDENTIFIER ASSIGN expression {
        Value myValue = $5.value;
        addSymbol($3, $2, true, myValue, true, false, NULL);
    }
    | CONST IDENTIFIER ASSIGN expression {
        report_error(SEMANTIC_ERROR, "Missing Type", prev_valid_line);
        fprintf(stderr, "Semantic Error (line %d): Constant '%s' declared without a type.\n", prev_valid_line, $2);
        // exit(1);
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

        FILE *output = fopen("symbol_table.txt", "w");
        if (output) {
            writeSymbolTableOfAllScopesToFile(output);
            fclose(output);
        } else {
            printf("Failed to open symbol_table.txt for writing.\n");
        }

        reportUnusedVariables();

        printf("\n=== Parsing Finished ===\n");
        print_all_errors();  

        if (get_error_count() > 0) {
            printf("Parsing failed with errors.\n");
        } else {
            printf("Parsing successful!\n");
        }

        fclose(input);
        clearSymbolTables(currentScope);
    } else {
        printf("Failed to open input file.\n");
    }
    return 0;
}