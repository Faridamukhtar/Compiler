%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "lex.yy.h"
#include "symbol_table.h"
#include "helpers.h"

extern int yylex();
extern int yyparse();

void yyerror(const char *s);

%}

%code requires {
    #include "symbol_table.h"
    #include "helpers.h"
}

%union {
    int i;
    char c;
    float f;
    char *s;
    expr expr;
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
    ;

declaration: 
    TYPE identifier_list  {
        // int x,y,z; $2 $1   x,y,z 
        int count =0;
        char** result = split($2, ",", &count); // remove spaces please
        if (result) {
            // printf("count %d", count);
            // printf("text %s", $2);
            Value myvalue;
            for (int i = 0; i < count; i++) {
                addSymbol(result[i], $1, myvalue, false, false, NULL, NULL);
            }
            free_split_result(result, count);
        } else {
            printf("Error splitting string\n");
        }
    }
    | TYPE IDENTIFIER ASSIGN expression {
        addSymbol($2, $1, $4.value, false, false, NULL, NULL);
    }
    ;

identifier_list: // capture el zft dah sa7 howa kman
    IDENTIFIER
    | identifier_list COMMA IDENTIFIER
    ;

assignment: // completely working expression bs ywsly sa7
    IDENTIFIER INC {
        handlePrefixInc($1);
    }
    | IDENTIFIER DEC {
        handlePostfixDec($1);
    }
    | INC IDENTIFIER {
        handlePrefixInc($2);
    }
    | DEC IDENTIFIER {
        handlePostfixDec($2);

    }
    | IDENTIFIER ASSIGN expression
    {
        updateSymbolValue($1, $3.value);
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
        Value myValue = $4.value;
        addSymbol($2, $1, myValue, true, false, NULL, NULL);
    }
    | TYPE IDENTIFIER {
        //8lt aslan ka rule (fofa)
        Value myValue;
        addSymbol($2, $1, myValue, false, false, NULL, NULL);
    }
    | IDENTIFIER ASSIGN expression {//play here -> update
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
    logical_expr OR logical_term {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement real OR
    }
    | logical_term {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: propagate term
    }
;

logical_term:
    logical_term AND equality_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement real AND
    }
    | equality_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: propagate equality
    }
;

equality_expr:
    equality_expr EQ relational_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement ==
    }
    | equality_expr NEQ relational_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement !=
    }
    | relational_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: propagate relational
    }
;

relational_expr:
    relational_expr LT additive_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement <
    }
    | relational_expr GT additive_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement >
    }
    | relational_expr LTE additive_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement <=
    }
    | relational_expr GTE additive_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement >=
    }
    | additive_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: propagate additive
    }
;

additive_expr:
    additive_expr PLUS multiplicative_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement +
    }
    | additive_expr MINUS multiplicative_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement -
    }
    | multiplicative_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: propagate multiplicative
    }
;

multiplicative_expr:
    multiplicative_expr MUL exponent_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement *
    }
    | multiplicative_expr DIV exponent_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement /
    }
    | exponent_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: propagate exponent
    }
;

exponent_expr:
    exponent_expr EXP unary_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement ^
    }
    | unary_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: propagate unary
    }
;

unary_expr:
    MINUS unary_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement -expr
    }
    | NOT unary_expr {
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true}; // TODO: implement !expr
    }
    | primary_expr { $$ = $1; }
    ;

primary_expr:
    INT {
        // printf("int %d\n", $1);
        Value val;
        val.iVal = $1;
        $$ = (expr){.type = INT_TYPE, .value = val};
    }
    | FLOAT {
        // printf("float %f\n", $1);
        Value val;
        val.fVal = $1;
        $$ = (expr){.type = FLOAT_TYPE, .value = val};
    }
    | CHAR {
        // printf("char '%c' (ascii: %d)\n", $1, $1);
        Value val;
        val.cVal = $1;
        $$ = (expr){.type = CHAR_TYPE, .value = val};
    }
    | BOOLEAN {
        // printf("bool %s\n", $1 ? "true" : "false");
        Value val;
        val.bVal = ($1 != 0);
        $$ = (expr){.type = BOOL_TYPE, .value = val};
    }
    | STRING {
        // printf("string \"%s\"\n", $1);
        Value val;
        val.sVal = strdup($1); // Make a copy
        $$ = (expr){.type = STRING_TYPE, .value = val};
    }
    | LPAREN expression RPAREN {
        $$ = $2; // Return inner expression directly
    }
    | function_call {
        // You should ideally evaluate the function and return its value
        // Here, using a placeholder
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true};
    }
    | IDENTIFIER {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry) {
            yyerror("Undeclared identifier");
            YYABORT;
        }

        // printf("identifier %s (type: %d)\n", $1, entry->type);
        $$ = (expr){.type = entry->type, .value = entry->value};
    }
;


repeat_stmt:
    REPEAT LBRACE statement_list RBRACE UNTIL LPAREN expression RPAREN SEMI
    ;

function_decl: //play here
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

param: //play here
    TYPE IDENTIFIER {
        Value myValue;
        addSymbol($2, $1, myValue, true, false, NULL, NULL);
    }
    ;

const_decl: 
    CONST TYPE IDENTIFIER ASSIGN expression { //values btwsal hena 8lt check + string and char fyhom azma
        Value myValue = $5.value;
        addSymbol($3, $2, myValue, true, false, NULL, NULL);
    }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Parse error: %s\n", s);
}

int main() {
    printf("Starting parser...\n");
    initSymbolTable(); // Add this line
    FILE *input = fopen("input.txt", "r");
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
        fclose(input);
        // Clean up symbol table
        clearSymbolTables(currentScope);
    } else {
        printf("Failed to open input file.\n");
    }
    return 0;
}