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
#include "quadruple.h"
#include "quad_to_asm.h"

extern int yylex();
extern int yyparse();
extern int prev_valid_line;

SymbolTableEntry* currentFunction = NULL;
ValueType currentFunctionReturnType = VOID_TYPE;

void yyerror(const char *s);

// Track current loop labels for break/continue
char *break_label_stack[100];
char *continue_label_stack[100];
int loop_label_top = -1;

char* get_break_label() {
    if (loop_label_top >= 0)
        return break_label_stack[loop_label_top];
    return NULL;
}

char* get_continue_label() {
    if (loop_label_top >= 0)
        return continue_label_stack[loop_label_top];
    return NULL;
}

void push_loop_labels(char *break_label, char *continue_label) {
    loop_label_top++;
    break_label_stack[loop_label_top] = break_label;
    continue_label_stack[loop_label_top] = continue_label;
}

void pop_loop_labels() {
    if (loop_label_top >= 0)
        loop_label_top--;
}

char *current_switch_var = NULL;
char *current_switch_end_label = NULL;
char *current_case_next_label = NULL;
char *default_label = NULL;

%}

%code requires {
    #include "symbol_table.h"
    #include "helpers.h"
    #include "parameter.h"
    #include "quadruple.h"
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
    struct {
        char *code;     
        char *true_label;
        char *false_label;
        char *next_label;
        char *start_label;
        char *end_label;
        char *cond_label;
        char *body_label;
        char *incr_label;
    } code_info;
    char *temp_var;
    void *void_val;
}

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
%token INC DEC

%type <expr> expression logical_expr logical_term equality_expr relational_expr additive_expr multiplicative_expr exponent_expr unary_expr primary_expr
%type <param_list> params param_list param
%type <s> identifier_list
%type <code_info> if_stmt else_part while_stmt while_header for_stmt switch_stmt repeat_stmt for_header for_body
%type <expr> CONSTANT_VAL
%type <temp_var> function_call
%type <void_val> statement_list case_list default_case
%type <param_list> argument_list

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
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

/* Grammar Rules */

program:
    statement_list
    ;

statement_list:
    /* empty */ { $$ = NULL; }
    | statement_list statement
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
    | CONTINUE SEMI {
        add_quadruple(OP_GOTO, get_continue_label(), NULL, NULL);
    }
        /* Generate code for continue - usually jumps to loop condition */
        /* This would need to keep track of current loop's continue label */

    | BREAK SEMI {
        add_quadruple(OP_GOTO, get_break_label(), NULL, NULL);
    }
        /* Generate code for break - usually jumps to end of loop */
        /* This would need to keep track of current loop's exit label */
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
    TYPE identifier_list {
        int count = 0;
        char** result = split($2, ",", &count);
        if (result) {
            Value myvalue;
            myvalue.iVal = 0; // Initialize to default
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
                Value myValue = $4.value;
                addSymbol($2, $1, true, myValue, false, false, NULL);
                char *expr_result;
                if ($4.temp_var) {
                    expr_result = $4.temp_var;
                } else {
                    expr_result = malloc(50);
                    switch ($4.type) {
                        case INT_TYPE: sprintf(expr_result, "%d", $4.value.iVal); break;
                        case FLOAT_TYPE: sprintf(expr_result, "%f", $4.value.fVal); break;
                        case BOOL_TYPE: sprintf(expr_result, "%s", $4.value.bVal ? "true" : "false"); break;
                        case CHAR_TYPE: sprintf(expr_result, "'%c'", $4.value.cVal); break;
                        case STRING_TYPE: sprintf(expr_result, "\"%s\"", $4.value.sVal); break;
                        default: strcpy(expr_result, "unknown");
                    }
                }
                add_quadruple(OP_ASSIGN, expr_result, NULL, $2);
                if (!$4.temp_var) {
                    free(expr_result);
                }
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
    | identifier_list COMMA IDENTIFIER {
        $$ = concat_with_comma($1,$3); //TODO:CHECK
        /* Append the new identifier to the list */
        //int len1 = strlen($1);
        //int len3 = strlen($3);
        //$$ = malloc(len1 + len3 + 2); /* +2 for the comma and null terminator */
        //strcpy($$, $1);
        //strcat($$, ",");
        //strcat($$, $3);
        //free($1); /* Free the old string */
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
            add_quadruple(OP_INC, $1, NULL, $1);
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
            add_quadruple(OP_DEC, $1, NULL, $1);
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
            add_quadruple(OP_INC, $2, NULL, $2);
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
            add_quadruple(OP_DEC, $2, NULL, $2);
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
                Value myValue = $3.value;
                updateSymbolValue($1, myValue);
                char *expr_result;
                if ($3.temp_var) {
                    expr_result = $3.temp_var;
                } else {
                    expr_result = malloc(50);
                    switch ($3.type) {
                        case INT_TYPE:
                            sprintf(expr_result, "%d", $3.value.iVal);
                            break;
                        case FLOAT_TYPE:
                            sprintf(expr_result, "%f", $3.value.fVal);
                            break;
                        case BOOL_TYPE:
                            sprintf(expr_result, "%s", $3.value.bVal ? "true" : "false");
                            break;
                        case CHAR_TYPE:
                            sprintf(expr_result, "'%c'", $3.value.cVal);
                            break;
                        case STRING_TYPE:
                            sprintf(expr_result, "\"%s\"", $3.value.sVal);
                            break;
                        default:
                            strcpy(expr_result, "unknown");
                    }
                }
                add_quadruple(OP_ASSIGN, expr_result, NULL, $1);
                if (!$3.temp_var) {
                    free(expr_result);
                }
            }
        }
    }

    | IDENTIFIER ASSIGN error {
        report_error(SYNTAX_ERROR, "Expected an expression", prev_valid_line);
        yyerrok;
    }
    ;

if_stmt:
    IF LPAREN expression RPAREN {
        char *true_label = new_label();
        char *false_label = new_label();
        char *next_label = new_label();

        // Emit conditional jump
        if ($3.temp_var) {
            add_quadruple(OP_IFGOTO, $3.temp_var, NULL, true_label);
        } else {
            char expr_result[50];
            switch ($3.type) {
                case INT_TYPE:   sprintf(expr_result, "%d", $3.value.iVal); break;
                case FLOAT_TYPE: sprintf(expr_result, "%f", $3.value.fVal); break;
                case BOOL_TYPE:  sprintf(expr_result, "%s", $3.value.bVal ? "true" : "false"); break;
                default:         strcpy(expr_result, "unknown");
            }
            add_quadruple(OP_IFGOTO, expr_result, NULL, true_label);
        }

        // Jump to else block if condition is false
        add_quadruple(OP_GOTO, NULL, NULL, false_label);
        add_quadruple(OP_LABEL, NULL, NULL, true_label);

        $<code_info>$ = (typeof($<code_info>$)){
            .true_label = true_label,
            .false_label = false_label,
            .next_label = next_label,
            .code = NULL
        };
    }
    LBRACE { enterScope(); }
    statement_list
    RBRACE { 
        exitScope(); 
        // End of 'then' block, jump to end of if-else
        add_quadruple(OP_GOTO, NULL, NULL, $<code_info>5.next_label);
        add_quadruple(OP_LABEL, NULL, NULL, $<code_info>5.false_label);
    }
    else_part {
        add_quadruple(OP_LABEL, NULL, NULL, $<code_info>5.next_label);
        // Emit any else statements
        if ($11.code != NULL) {
            $$.code = $11.code;
        }

        // Free all labels
        free($<code_info>5.true_label);
        free($<code_info>5.false_label);
        free($<code_info>5.next_label);
    }
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
    ELSE LBRACE {
        enterScope();
    } statement_list RBRACE {
        exitScope();
        $$.code = strdup("else_block");
    }
    | ELSE if_stmt {
        $$.code = $2.code;
    }
    | /* empty */ {
        $$.code = NULL;
    }
    ;

while_stmt:
    WHILE while_header LPAREN expression {
        // Evaluate expression ($4)
        expr condition = $<expr>4;
        // Emit condition label
        add_quadruple(OP_LABEL, NULL, NULL, $<code_info>2.cond_label);

        if (condition.temp_var) {
            add_quadruple(OP_IFGOTO, condition.temp_var, NULL, $<code_info>2.body_label);
        } else {
            char buffer[50];
            switch (condition.type) {
                case INT_TYPE:   sprintf(buffer, "%d", condition.value.iVal); break;
                case FLOAT_TYPE: sprintf(buffer, "%f", condition.value.fVal); break;
                case BOOL_TYPE:  sprintf(buffer, "%s", condition.value.bVal ? "true" : "false"); break;
                default:         strcpy(buffer, "unknown");
            }
            add_quadruple(OP_IFGOTO, buffer, NULL, $<code_info>2.body_label);
        }

        // Labels were created earlier and stored in $<code_info>2
        add_quadruple(OP_GOTO, NULL, NULL, $<code_info>2.end_label);
        add_quadruple(OP_LABEL, NULL, NULL, $<code_info>2.body_label);

    } RPAREN LBRACE { enterScope(); } statement_list RBRACE {
        exitScope();

        // Jump back to condition after body
        add_quadruple(OP_GOTO, NULL, NULL, $2.cond_label);

        // Emit end label
        add_quadruple(OP_LABEL, NULL, NULL, $2.end_label);

        // Free dynamically allocated labels
        free($2.cond_label);
        free($2.body_label);
        free($2.end_label);
    }
    | WHILE while_header error {
        report_error(SYNTAX_ERROR, "Expected '(' in while condition", prev_valid_line);
        yyerrok;
    }
    | WHILE while_header LPAREN expression error LBRACE { enterScope(); } statement_list RBRACE {
        exitScope();
        report_error(SYNTAX_ERROR, "Expected ')' in while condition", prev_valid_line);
        yyerrok;
    }
;

while_header:
    /* empty */ {
        // Generate start and condition labels before expression is even parsed
        char *cond_label  = new_label();
        char *body_label  = new_label();
        char *end_label  = new_label();

        // Pass all labels
        $$.cond_label  = cond_label;
        $$.body_label  = body_label;
        $$.end_label  = end_label;
    }
    ;

for_stmt:
    FOR LPAREN for_header assignment RPAREN for_body {
        // Now emit the loop logic from here using $3 (header data)

        // Jump back to condition
        add_quadruple(OP_GOTO, NULL, NULL, $3.cond_label);

        // End label
        add_quadruple(OP_LABEL, NULL, NULL, $3.end_label);

        // Clean up
        free($3.cond_label);
        free($3.body_label);
        free($3.end_label);
    }
    | FOR error for_header assignment RPAREN for_body {
        report_error(SYNTAX_ERROR, "Expected '(' in for loop", prev_valid_line);
        yyerrok;
    }
    | FOR LPAREN for_header assignment error {
        report_error(SYNTAX_ERROR, "Expected ')' in for loop", prev_valid_line);
        yyerrok;
    }


;

for_header:
    for_stmt_declaration SEMI expression SEMI
    {
        char *cond_label = new_label();
        char *body_label = new_label();
        char *end_label  = new_label();

        add_quadruple(OP_LABEL, NULL, NULL, cond_label);

        if ($3.temp_var) {
            add_quadruple(OP_IFGOTO, $3.temp_var, NULL, body_label);
        } else {
            char buffer[50];
            sprintf(buffer, "%d", $3.value.iVal); // adjust based on type
            add_quadruple(OP_IFGOTO, buffer, NULL, body_label);
        }

        add_quadruple(OP_GOTO, NULL, NULL, end_label);
        add_quadruple(OP_LABEL, NULL, NULL, body_label);

        // Pass info to for_body
        $$.cond_label = cond_label;
        $$.body_label = body_label;
        $$.end_label = end_label;
    }
    | for_stmt_declaration error expression SEMI {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    | for_stmt_declaration SEMI expression error {
        report_error(SYNTAX_ERROR, "Expected ';'", prev_valid_line);
        yyerrok;
    }
    ;

for_body:
    LBRACE { enterScope(); } statement_list RBRACE { exitScope(); }
;

for_stmt_declaration:
    TYPE IDENTIFIER ASSIGN expression {
        Value myValue = $4.value;
        addSymbol($2, $1, true, myValue, false, false, NULL);
        char *expr_result;
        if ($4.temp_var) {
            expr_result = $4.temp_var;
        } else {
            expr_result = malloc(50);
            switch ($4.type) {
                case INT_TYPE:
                    sprintf(expr_result, "%d", $4.value.iVal);
                    break;
                case FLOAT_TYPE:
                    sprintf(expr_result, "%f", $4.value.fVal);
                    break;
                case BOOL_TYPE:
                    sprintf(expr_result, "%s", $4.value.bVal ? "true" : "false");
                    break;
                case CHAR_TYPE:
                    sprintf(expr_result, "'%c'", $4.value.cVal);
                    break;
                case STRING_TYPE:
                    sprintf(expr_result, "\"%s\"", $4.value.sVal);
                    break;
                default:
                    strcpy(expr_result, "unknown");
            }
        }
        add_quadruple(OP_ASSIGN, expr_result, NULL, $2);
        if (!$4.temp_var) {
            free(expr_result);
        }
    }
    | TYPE IDENTIFIER {
        Value myValue;
        myValue.iVal = 0; // Initialize to default
        addSymbol($2, $1, false, myValue, false, false, NULL);
        }    
    | IDENTIFIER ASSIGN expression {
        Value myValue = $3.value;
        updateSymbolValue($1, myValue);
        char *expr_result;
        if ($3.temp_var) {
            expr_result = $3.temp_var;
        } else {
            expr_result = malloc(50);
            switch ($3.type) {
                case INT_TYPE:
                    sprintf(expr_result, "%d", $3.value.iVal);
                    break;
                case FLOAT_TYPE:
                    sprintf(expr_result, "%f", $3.value.fVal);
                    break;
                case BOOL_TYPE:
                    sprintf(expr_result, "%s", $3.value.bVal ? "true" : "false");
                    break;
                case CHAR_TYPE:
                    sprintf(expr_result, "'%c'", $3.value.cVal);
                    break;
                case STRING_TYPE:
                    sprintf(expr_result, "\"%s\"", $3.value.sVal);
                    break;
                default:
                    strcpy(expr_result, "unknown");
            }
        }
        add_quadruple(OP_ASSIGN, expr_result, NULL, $1);
        if (!$3.temp_var) {
            free(expr_result);
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
    | IDENTIFIER ASSIGN error {
        report_error(SYNTAX_ERROR, "Expected expression after assignment", prev_valid_line);
        yyerrok;
    }
    ;

CONSTANT_VAL:
      INT      { Value v; v.iVal = $1; $$ = (expr){.type = INT_TYPE, .value = v, .temp_var = NULL}; }
    | FLOAT    { Value v; v.fVal = $1; $$ = (expr){.type = FLOAT_TYPE, .value = v, .temp_var = NULL}; }
    | BOOLEAN  { Value v; v.bVal = $1; $$ = (expr){.type = BOOL_TYPE, .value = v, .temp_var = NULL}; }
    | IDENTIFIER {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry) {
            fprintf(stderr, "Semantic Error (line %d): Variable '%s' not declared.\n", prev_valid_line, $1);
            YYABORT;
        }
        $$ = (expr){.type = entry->type, .value = entry->value, .temp_var = strdup($1)};
    }
;
switch_stmt:
    SWITCH LPAREN IDENTIFIER RPAREN {
        current_switch_end_label = new_label();
        $<code_info>$ = (typeof($<code_info>$)){
            .code = strdup($3),     // variable to match
            .end_label = current_switch_end_label,
            .true_label = NULL,
            .false_label = NULL,
            .next_label = NULL
        };
    } LBRACE { enterScope(); } case_list default_case RBRACE {
        exitScope();
        add_quadruple(OP_LABEL, NULL, NULL, $<code_info>5.end_label);
        free($<code_info>5.end_label);
        free($<code_info>5.code);
    }
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
    /* empty */ { $$ = NULL; }
    | case_list case_item
;

case_item:
    CASE CONSTANT_VAL COLON {
        char *case_label = new_label();
        char *next_case_label = new_label();
        char *val_str = malloc(50);

        switch ($2.type) {
            case INT_TYPE:   sprintf(val_str, "%d", $2.value.iVal); break;
            case FLOAT_TYPE: sprintf(val_str, "%f", $2.value.fVal); break;
            case BOOL_TYPE:  sprintf(val_str, "%s", $2.value.bVal ? "true" : "false"); break;
            case CHAR_TYPE:  sprintf(val_str, "'%c'", $2.value.cVal); break;
            case STRING_TYPE:sprintf(val_str, "\"%s\"", $2.value.sVal); break;
            default:          strcpy(val_str, "unknown");
        }

        // t = switch_var == case_val
        char *temp = new_temp();
        add_quadruple(OP_EQ, current_switch_var, val_str, temp);

        // if t goto case_label, else goto next
        add_quadruple(OP_IFGOTO, temp, NULL, case_label);
        add_quadruple(OP_GOTO, NULL, NULL, next_case_label);
        add_quadruple(OP_LABEL, NULL, NULL, case_label);

        current_case_next_label = next_case_label;
        free(val_str);
    } statement_list {
        add_quadruple(OP_GOTO, NULL, NULL, current_switch_end_label);
        add_quadruple(OP_LABEL, NULL, NULL, current_case_next_label);
    }
    | CASE CONSTANT_VAL error {
        report_error(SYNTAX_ERROR, "Expected ':'", prev_valid_line);
        yyerrok;
    }
    | CASE error {
        report_error(SYNTAX_ERROR, "Invalid constant in switch case", prev_valid_line);
        yyerrok;
    }
    ;

default_case:
    DEFAULT COLON {
        default_label = new_label();
        add_quadruple(OP_LABEL, NULL, NULL, default_label);
    } statement_list {
        add_quadruple(OP_GOTO, NULL, NULL, current_switch_end_label);
    }
    | DEFAULT error {
        report_error(SYNTAX_ERROR, "Expected ':'", prev_valid_line);
        yyerrok;
    }
    | /* empty */ { $$ = NULL; }
    ;

return_stmt:
    RETURN expression {
        /* Generate return quadruple */
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
        if ($2.temp_var) {
            add_quadruple(OP_RETURN, $2.temp_var, NULL, NULL);
        } else {
            /* Convert value to string */
            char *val_str = malloc(50);
            switch ($2.type) {
                case INT_TYPE:
                    sprintf(val_str, "%d", $2.value.iVal);
                    break;
                case FLOAT_TYPE:
                    sprintf(val_str, "%f", $2.value.fVal);
                    break;
                case BOOL_TYPE:
                    sprintf(val_str, "%s", $2.value.bVal ? "true" : "false");
                    break;
                case CHAR_TYPE:
                    sprintf(val_str, "'%c'", $2.value.cVal);
                    break;
                case STRING_TYPE:
                    sprintf(val_str, "\"%s\"", $2.value.sVal);
                    break;
                default:
                    strcpy(val_str, "unknown");
                }
                add_quadruple(OP_RETURN, val_str, NULL, NULL);
                free(val_str);
            }
        
    }
    | RETURN {
        if (currentFunctionReturnType != VOID_TYPE) {
            report_error(SEMANTIC_ERROR, "Missing Return Value", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Function '%s' must return nothing (void).\n",
                    prev_valid_line,
                    currentFunction ? currentFunction->identifierName : "unknown");
        }
        /* Generate empty return quadruple */
        add_quadruple(OP_RETURN, NULL, NULL, NULL);
    }
    ;

expression:
    logical_expr { $$ = $1; }
    ;

logical_expr:
    logical_expr OR logical_term {
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_OR, $1.temp_var, $3.temp_var, temp);
        } else {
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    case BOOL_TYPE: sprintf(arg1, "%s", $1.value.bVal ? "true" : "false"); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    case BOOL_TYPE: sprintf(arg2, "%s", $3.value.bVal ? "true" : "false"); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_OR, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        $$.type = BOOL_TYPE;
        $$.value.bVal = true;
        $$.temp_var = temp;
    }
    | logical_term { $$ = $1; }
    ;

logical_term:
    logical_term AND equality_expr {
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_AND, $1.temp_var, $3.temp_var, temp);
        } else {
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    case BOOL_TYPE: sprintf(arg1, "%s", $1.value.bVal ? "true" : "false"); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    case BOOL_TYPE: sprintf(arg2, "%s", $3.value.bVal ? "true" : "false"); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_AND, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        $$.type = BOOL_TYPE;
        $$.value.bVal = true;
        $$.temp_var = temp;
    }
    | equality_expr { $$ = $1; }
    ;

equality_expr:
    equality_expr EQ relational_expr {
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_EQ, $1.temp_var, $3.temp_var, temp);
        } else {
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    case BOOL_TYPE: sprintf(arg1, "%s", $1.value.bVal ? "true" : "false"); break;
                    case CHAR_TYPE: sprintf(arg1, "'%c'", $1.value.cVal); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    case BOOL_TYPE: sprintf(arg2, "%s", $3.value.bVal ? "true" : "false"); break;
                    case CHAR_TYPE: sprintf(arg2, "'%c'", $3.value.cVal); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_EQ, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        $$.type = BOOL_TYPE;
        $$.value.bVal = true;
        $$.temp_var = temp;
    }
    | equality_expr NEQ relational_expr {
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_NEQ, $1.temp_var, $3.temp_var, temp);
        } else {
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    case BOOL_TYPE: sprintf(arg1, "%s", $1.value.bVal ? "true" : "false"); break;
                    case CHAR_TYPE: sprintf(arg1, "'%c'", $1.value.cVal); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    case BOOL_TYPE: sprintf(arg2, "%s", $3.value.bVal ? "true" : "false"); break;
                    case CHAR_TYPE: sprintf(arg2, "'%c'", $3.value.cVal); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_NEQ, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        $$.type = BOOL_TYPE;
        $$.value.bVal = true;
        $$.temp_var = temp;
    }
    | relational_expr { $$ = $1; }
    ;

relational_expr:
    relational_expr LT additive_expr {
        /* Generate quadruple for less than comparison */
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_LT, $1.temp_var, $3.temp_var, temp);
        } else {
            /* Handle literals or expressions without temp vars */
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_LT, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        /* Create a new expression with the temp var */
        $$.type = BOOL_TYPE;
        $$.value.bVal = true;  /* Default value */
        $$.temp_var = temp;
    }
    | relational_expr GT additive_expr {
        /* Generate quadruple for greater than comparison */
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_GT, $1.temp_var, $3.temp_var, temp);
        } else {
            /* Handle literals or expressions without temp vars */
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_GT, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        /* Create a new expression with the temp var */
        $$.type = BOOL_TYPE;
        $$.value.bVal = true;  /* Default value */
        $$.temp_var = temp;
    }
    | relational_expr LTE additive_expr {
        /* Generate quadruple for less than or equal comparison */
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_LTE, $1.temp_var, $3.temp_var, temp);
        } else {
            /* Handle literals or expressions without temp vars */
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_LTE, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        /* Create a new expression with the temp var */
        $$.type = BOOL_TYPE;
        $$.value.bVal = true;  /* Default value */
        $$.temp_var = temp;
    }
    | relational_expr GTE additive_expr {
        /* Generate quadruple for greater than or equal comparison */
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_GTE, $1.temp_var, $3.temp_var, temp);
        } else {
            /* Handle literals or expressions without temp vars */
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_GTE, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        /* Create a new expression with the temp var */
        $$.type = BOOL_TYPE;
        $$.value.bVal = true;  /* Default value */
        $$.temp_var = temp;
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
        else
        {
            /* Generate quadruple for addition */
            char *temp = new_temp();
            if ($1.temp_var && $3.temp_var) {
                add_quadruple(OP_ADD, $1.temp_var, $3.temp_var, temp);
            } else {
                /* Handle literals or expressions without temp vars */
                char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
                char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
                
                if (!$1.temp_var) {
                    switch ($1.type) {
                        case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                        case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                        default: strcpy(arg1, "unknown");
                    }
                }
                
                if (!$3.temp_var) {
                    switch ($3.type) {
                        case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                        case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                        default: strcpy(arg2, "unknown");
                    }
                }
                
                add_quadruple(OP_ADD, arg1, arg2, temp);
                
                if (!$1.temp_var) free(arg1);
                if (!$3.temp_var) free(arg2);
            }
            
            /* Determine the type of the result */
            if ($1.type == FLOAT_TYPE || $3.type == FLOAT_TYPE) {
                $$.type = FLOAT_TYPE;
                $$.value.fVal = ($1.type == FLOAT_TYPE ? $1.value.fVal : (float)$1.value.iVal) + 
                            ($3.type == FLOAT_TYPE ? $3.value.fVal : (float)$3.value.iVal);
            } else {
                $$.type = INT_TYPE;
                $$.value.iVal = $1.value.iVal + $3.value.iVal;
            }
            $$.temp_var = temp;
        }
    }
    | additive_expr MINUS multiplicative_expr {
        if (!areTypesCompatible($1.type, $3.type)) {
            report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Incompatible types in subtraction.\n", prev_valid_line);
        }
        else
        {
             /* Generate quadruple for subtraction */
            char *temp = new_temp();
            if ($1.temp_var && $3.temp_var) {
                add_quadruple(OP_SUB, $1.temp_var, $3.temp_var, temp);
            } else {
                /* Handle literals or expressions without temp vars */
                char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
                char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
                
                if (!$1.temp_var) {
                    switch ($1.type) {
                        case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                        case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                        default: strcpy(arg1, "unknown");
                    }
                }
                
                if (!$3.temp_var) {
                    switch ($3.type) {
                        case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                        case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                        default: strcpy(arg2, "unknown");
                    }
                }
                
                add_quadruple(OP_SUB, arg1, arg2, temp);
                
                if (!$1.temp_var) free(arg1);
                if (!$3.temp_var) free(arg2);
            }
            
            /* Determine the type of the result */
            if ($1.type == FLOAT_TYPE || $3.type == FLOAT_TYPE) {
                $$.type = FLOAT_TYPE;
                $$.value.fVal = ($1.type == FLOAT_TYPE ? $1.value.fVal : (float)$1.value.iVal) - 
                            ($3.type == FLOAT_TYPE ? $3.value.fVal : (float)$3.value.iVal);
            } else {
                $$.type = INT_TYPE;
                $$.value.iVal = $1.value.iVal - $3.value.iVal;
            }
            $$.temp_var = temp;
        }
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
        else
        {
        /* Generate quadruple for multiplication */
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_MUL, $1.temp_var, $3.temp_var, temp);
        } else {
            /* Handle literals or expressions without temp vars */
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_MUL, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        /* Determine the type of the result */
        if ($1.type == FLOAT_TYPE || $3.type == FLOAT_TYPE) {
            $$.type = FLOAT_TYPE;
            $$.value.fVal = ($1.type == FLOAT_TYPE ? $1.value.fVal : (float)$1.value.iVal) * 
                           ($3.type == FLOAT_TYPE ? $3.value.fVal : (float)$3.value.iVal);
        } else {
            $$.type = INT_TYPE;
            $$.value.iVal = $1.value.iVal * $3.value.iVal;
        }
        $$.temp_var = temp;
        }
    }
    | multiplicative_expr DIV exponent_expr {
    if (!areTypesCompatible($1.type, $3.type)) {
        report_error(SEMANTIC_ERROR, "Incompatible Types", prev_valid_line);
        fprintf(stderr, "Semantic Error (line %d): Incompatible types in division.\n", prev_valid_line);
    }
    else
    {
        /* Check for division by zero */
        if (($3.type == INT_TYPE && $3.value.iVal == 0) || 
            ($3.type == FLOAT_TYPE && $3.value.fVal == 0.0)) {
            fprintf(stderr, "Semantic Error (line %d): Division by zero.\n", prev_valid_line);
        }
        
        /* Generate quadruple for division */
        char *temp = new_temp();
        if ($1.temp_var && $3.temp_var) {
            add_quadruple(OP_DIV, $1.temp_var, $3.temp_var, temp);
        } else {
            /* Handle literals or expressions without temp vars */
            char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
            char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
            
            if (!$1.temp_var) {
                switch ($1.type) {
                    case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                    default: strcpy(arg1, "unknown");
                }
            }
            
            if (!$3.temp_var) {
                switch ($3.type) {
                    case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                    case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                    default: strcpy(arg2, "unknown");
                }
            }
            
            add_quadruple(OP_DIV, arg1, arg2, temp);
            
            if (!$1.temp_var) free(arg1);
            if (!$3.temp_var) free(arg2);
        }
        
        /* Determine the type of the result */
        if ($1.type == FLOAT_TYPE || $3.type == FLOAT_TYPE) {
            $$.type = FLOAT_TYPE;
            $$.value.fVal = ($1.type == FLOAT_TYPE ? $1.value.fVal : (float)$1.value.iVal) / 
                           ($3.type == FLOAT_TYPE ? $3.value.fVal : (float)$3.value.iVal);
        } else {
            $$.type = INT_TYPE;
            $$.value.iVal = $1.value.iVal / $3.value.iVal;
        }
        $$.temp_var = temp;
    }
}

| multiplicative_expr MOD exponent_expr {
    /* Check for modulo by zero */
    if (($3.type == INT_TYPE && $3.value.iVal == 0) || 
        ($3.type == FLOAT_TYPE && $3.value.fVal == 0.0)) {
        fprintf(stderr, "Semantic Error (line %d): Modulo by zero.\n", prev_valid_line);
    }
    
    /* Generate quadruple for modulo */
    char *temp = new_temp();
    if ($1.temp_var && $3.temp_var) {
        add_quadruple(OP_MOD, $1.temp_var, $3.temp_var, temp);
    } else {
        /* Handle literals or expressions without temp vars */
        char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
        char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
        
        if (!$1.temp_var) {
            switch ($1.type) {
                case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                default: strcpy(arg1, "unknown");
            }
        }
        
        if (!$3.temp_var) {
            switch ($3.type) {
                case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                default: strcpy(arg2, "unknown");
            }
        }
        
        add_quadruple(OP_MOD, arg1, arg2, temp);
        
        if (!$1.temp_var) free(arg1);
        if (!$3.temp_var) free(arg2);
    }
    
    /* Modulo only works on integers */
    $$.type = INT_TYPE;
    $$.value.iVal = $1.value.iVal % $3.value.iVal;
    $$.temp_var = temp;
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
        else
        {
            /* Generate quadruple for exponentiation */
            char *temp = new_temp();
            if ($1.temp_var && $3.temp_var) {
                add_quadruple(OP_EXP, $1.temp_var, $3.temp_var, temp);
            } else {
                /* Handle literals or expressions without temp vars */
                char *arg1 = $1.temp_var ? $1.temp_var : malloc(50);
                char *arg2 = $3.temp_var ? $3.temp_var : malloc(50);
                
                if (!$1.temp_var) {
                    switch ($1.type) {
                        case INT_TYPE: sprintf(arg1, "%d", $1.value.iVal); break;
                        case FLOAT_TYPE: sprintf(arg1, "%f", $1.value.fVal); break;
                        default: strcpy(arg1, "unknown");
                    }
                }
                
                if (!$3.temp_var) {
                    switch ($3.type) {
                        case INT_TYPE: sprintf(arg2, "%d", $3.value.iVal); break;
                        case FLOAT_TYPE: sprintf(arg2, "%f", $3.value.fVal); break;
                        default: strcpy(arg2, "unknown");
                    }
                }
                
                add_quadruple(OP_EXP, arg1, arg2, temp);
                
                if (!$1.temp_var) free(arg1);
                if (!$3.temp_var) free(arg2);
            }
            
            /* For simplicity, result is float */
            $$.type = FLOAT_TYPE;
            /* Actual computation would be done by the target language */
            $$.value.fVal = 0.0;  /* Placeholder */
            $$.temp_var = temp;
        }
    }
    | unary_expr {
        $$ = $1;
    }
    ;

unary_expr:
    MINUS unary_expr {
        /* Generate quadruple for unary minus */
        char *temp = new_temp();
        if ($2.temp_var) {
            add_quadruple(OP_UMINUS, $2.temp_var, NULL, temp);
        } else {
            /* Handle literal or expression without temp var */
            char *arg = malloc(50);
            
            switch ($2.type) {
                case INT_TYPE: sprintf(arg, "%d", $2.value.iVal); break;
                case FLOAT_TYPE: sprintf(arg, "%f", $2.value.fVal); break;
                default: strcpy(arg, "unknown");
            }
            
            add_quadruple(OP_UMINUS, arg, NULL, temp);
            free(arg);
        }
        
        /* Create a new expression with the temp var */
        if ($2.type == FLOAT_TYPE) {
            $$.type = FLOAT_TYPE;
            $$.value.fVal = -$2.value.fVal;
        } else {
            $$.type = INT_TYPE;
            $$.value.iVal = -$2.value.iVal;
        }
        $$.temp_var = temp;
    }
    | NOT unary_expr {
        /* Generate quadruple for logical NOT */
        char *temp = new_temp();
        if ($2.temp_var) {
            add_quadruple(OP_NOT, $2.temp_var, NULL, temp);
        } else {
            /* Handle literal or expression without temp var */
            char *arg = malloc(50);
            
            switch ($2.type) {
                case BOOL_TYPE: sprintf(arg, "%s", $2.value.bVal ? "true" : "false"); break;
                case INT_TYPE: sprintf(arg, "%d", $2.value.iVal); break;
                default: strcpy(arg, "unknown");
            }
            
            add_quadruple(OP_NOT, arg, NULL, temp);
            free(arg);
        }
        
        /* Create a new expression with the temp var */
        $$.type = BOOL_TYPE;
        $$.value.bVal = !$2.value.bVal;
        $$.temp_var = temp;
    }
    | primary_expr { 
        $$ = $1; 
    }
    ;
primary_expr:
    INT {
        Value val;
        val.iVal = $1;
        $$ = (expr){.type = INT_TYPE, .value = val, .temp_var = NULL};
    }
    | FLOAT {
        Value val;
        val.fVal = $1;
        $$ = (expr){.type = FLOAT_TYPE, .value = val, .temp_var = NULL};
    }
    | CHAR {
        Value val;
        val.cVal = $1;
        $$ = (expr){.type = CHAR_TYPE, .value = val, .temp_var = NULL};
    }
    | BOOLEAN {
        Value val;
        val.bVal = ($1 != 0);
        $$ = (expr){.type = BOOL_TYPE, .value = val, .temp_var = NULL};
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
        $$ = (expr){.type = STRING_TYPE, .value = val, .temp_var = NULL};
    }
    | LPAREN expression RPAREN {
        $$ = $2; 
    }
    | function_call {
        //TODO: FIX THIS -> MIRA: $$ = $1; 
        $$ = (expr){.type = BOOL_TYPE, .value.bVal = true, .temp_var = $1};
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
            $$ = (expr){.type = entry->type, .value = entry->value, .temp_var = strdup($1)};
        }
    }
    ;

repeat_stmt: REPEAT LBRACE {
    enterScope();
    /* Generate start label for repeat loop */
    char *start_label = new_label();
    add_quadruple(OP_LABEL, NULL, NULL, start_label);
    $<code_info>$.code = start_label;
} statement_list RBRACE UNTIL LPAREN expression RPAREN SEMI {
    exitScope();
    /* Generate condition code */
    char *end_label = new_label();
    
    /* If expression has a temp variable */
    if ($8.temp_var) {
        add_quadruple(OP_IFGOTO, $8.temp_var, NULL, end_label);
    } else {
        /* Create a comparison with true */
        char *expr_result = malloc(50);
        switch ($8.type) {
            case INT_TYPE:
                sprintf(expr_result, "%d", $8.value.iVal);
                break;
            case FLOAT_TYPE:
                sprintf(expr_result, "%f", $8.value.fVal);
                break;
            case BOOL_TYPE:
                sprintf(expr_result, "%s", $8.value.bVal ? "true" : "false");
                break;
            default:
                strcpy(expr_result, "unknown");
        }
        add_quadruple(OP_IFGOTO, expr_result, NULL, end_label);
        free(expr_result);
    }
    
    /* Jump back to start of loop */
    add_quadruple(OP_GOTO, NULL, NULL, $<code_info>3.code);
    add_quadruple(OP_LABEL, NULL, NULL, end_label);
    
    /* Clean up */
    free($<code_info>3.code);
    free(end_label);
    }
    ;

function_decl:
    FUNCTION TYPE IDENTIFIER LPAREN params RPAREN LBRACE {
        Value myValue;
        myValue.iVal = 0;  // Initialize with a default value
        addSymbol($3, $2, true, myValue, false, true, $5); 
        currentFunction = lookupSymbol($3);
        currentFunctionReturnType = mapStringToValueType($2);
        enterScope();
        addParamsToSymbolTable($5);
        add_quadruple(OP_LABEL, $3, NULL, NULL);
    } statement_list RBRACE {
        /* Generate implicit return if none exists */
        add_quadruple(OP_RETURN, NULL, NULL, NULL);
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
            /* $$ = (expr){.type = BOOL_TYPE}; */
        } else {
            entry->isUsed = true;
            if (!compareParameters(entry->params, $3)) {
                report_error(SEMANTIC_ERROR, "Function Argument Mismatch", prev_valid_line);
                fprintf(stderr, "Semantic Error (line %d): Arguments passed to function '%s' do not match its definition.\n", prev_valid_line, $1);
            }
            /* $$ = (expr){.type = entry->type, .value = (Value){}}; */
        }
        /* Generate function call quadruple */
        char *result = new_temp();
        add_quadruple(OP_CALL, $1, NULL, result);
        
        /* Store result in a temporary var for later use */
        $<temp_var>$ = result;
    }
    | IDENTIFIER LPAREN RPAREN {
        SymbolTableEntry *entry = lookupSymbol($1);
        if (!entry || !entry->isFunction) {
            report_error(SEMANTIC_ERROR, "Invalid Function Call", prev_valid_line);
            fprintf(stderr, "Semantic Error (line %d): Function '%s' is not declared.\n", prev_valid_line, $1);
            //$$ = (expr){.type = BOOL_TYPE};
        } else {
            entry->isUsed = true;
            if (entry->params != NULL) {
                report_error(SEMANTIC_ERROR, "Function Argument Mismatch", prev_valid_line);
                fprintf(stderr, "Semantic Error (line %d): Function '%s' expects arguments, but none were given.\n", prev_valid_line, $1);
            }
           // $$ = (expr){.type = entry->type, .value = (Value){}};
        }
        /* Generate function call quadruple with no arguments */
        char *result = new_temp();
        add_quadruple(OP_CALL, $1, NULL, result);
        
        /* Store result in a temporary var for later use */
        $<temp_var>$ = result;
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
    argument_list COMMA expression {
        const char* t = typeToString($3.type);
        Parameter* arg = createParameter("arg", strdup(t));
        $$ = addParameter($1, arg);
        /* Generate parameter passing quadruple */
        if ($3.temp_var) {
            add_quadruple(OP_PARAM, $3.temp_var, NULL, NULL);
        } else {
            /* Convert literal value to string */
            char *param_val = malloc(50);
            switch ($3.type) {
                case INT_TYPE: sprintf(param_val, "%d", $3.value.iVal); break;
                case FLOAT_TYPE: sprintf(param_val, "%f", $3.value.fVal); break;
                case BOOL_TYPE: sprintf(param_val, "%s", $3.value.bVal ? "true" : "false"); break;
                case CHAR_TYPE: sprintf(param_val, "'%c'", $3.value.cVal); break;
                case STRING_TYPE: sprintf(param_val, "\"%s\"", $3.value.sVal); break;
                default: strcpy(param_val, "unknown");
            }
            add_quadruple(OP_PARAM, param_val, NULL, NULL);
            free(param_val);
        }
    }
    | expression {
        const char* t = typeToString($1.type);
        $$ = createParameter("arg", strdup(t));
        /* Generate parameter passing quadruple */
        if ($1.temp_var) {
            add_quadruple(OP_PARAM, $1.temp_var, NULL, NULL);
        } else {
            /* Convert literal value to string */
            char *param_val = malloc(50);
            switch ($1.type) {
                case INT_TYPE: sprintf(param_val, "%d", $1.value.iVal); break;
                case FLOAT_TYPE: sprintf(param_val, "%f", $1.value.fVal); break;
                case BOOL_TYPE: sprintf(param_val, "%s", $1.value.bVal ? "true" : "false"); break;
                case CHAR_TYPE: sprintf(param_val, "'%c'", $1.value.cVal); break;
                case STRING_TYPE: sprintf(param_val, "\"%s\"", $1.value.sVal); break;
                default: strcpy(param_val, "unknown");
            }
            add_quadruple(OP_PARAM, param_val, NULL, NULL);
            free(param_val);
        }
    }
    ;


params:
    /* empty */ { $$ = NULL; }
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
        myValue.iVal = 0; // Initialize to default
        addSymbol($2, $1, false, myValue, true, false, NULL);
        $$ = createParameter($2, $1);  // Create a new parameter
    }
    ;

const_decl:
    CONST TYPE IDENTIFIER ASSIGN expression {
        /* Generate quadruple for constant assignment */
        if ($5.temp_var) {
            add_quadruple(OP_ASSIGN, $5.temp_var, NULL, $3);
        } else {
            /* Convert literal value to string */
            char *val_str = malloc(50);
            switch ($5.type) {
                case INT_TYPE: sprintf(val_str, "%d", $5.value.iVal); break;
                case FLOAT_TYPE: sprintf(val_str, "%f", $5.value.fVal); break;
                case BOOL_TYPE: sprintf(val_str, "%s", $5.value.bVal ? "true" : "false"); break;
                case CHAR_TYPE: sprintf(val_str, "'%c'", $5.value.cVal); break;
                case STRING_TYPE: sprintf(val_str, "\"%s\"", $5.value.sVal); break;
                default: strcpy(val_str, "unknown");
            }
            add_quadruple(OP_ASSIGN, val_str, NULL, $3);
            free(val_str);
        }
        
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
        yyparse();
        checkUnclosedScopes(yylineno);
        printf("\n=== Parsing Finished ===\n");
        print_all_errors();  

        if (get_error_count() > 0) {
            printf("Parsing failed with errors.\n");
        } else {
            printf("Parsing successful!\n");
        }

        // TODO: MOVE THIS INSIDE PREVIOUS ELSE
        // ------------------------------------------------------------------------------------------//

        print_quadruples();


        // Write quadruples to file
        FILE *quad_output = fopen("quadruples.txt", "w");
        if (quad_output) {
            fprintf(quad_output, "=== Generated Quadruples ===\n");
            for (int i = 0; i < quad_count; i++) {
                fprintf(quad_output, "[%d] (%s, %s, %s, %s)\n", i,
                    get_op_string(quadruples[i].op),
                    quadruples[i].arg1 ? quadruples[i].arg1 : "_",
                    quadruples[i].arg2 ? quadruples[i].arg2 : "_",
                    quadruples[i].result ? quadruples[i].result : "_"
                );
            }
            fclose(quad_output);
            printf("Quadruples written to quadruples.txt\n");
        }

        // Convert quadruples to assembly
        convert_quadruples_to_assembly("output.asm");
        printf("Assembly code written to output.asm\n");

        // ------------------------------------------------------------------------------------------//

        FILE *output = fopen("symbol_table.txt", "w");
        if (output) {
            writeSymbolTableOfAllScopesToFile(output);
            fclose(output);
        } else {
            printf("Failed to open symbol_table.txt for writing.\n");
        }

        reportUnusedVariables();
        fclose(input);
        clearSymbolTables(currentScope);
    } else {
        printf("Failed to open input file.\n");
    }
    return 0;
}