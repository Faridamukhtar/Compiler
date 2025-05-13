#include "quadruple.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Quadruple quadruples[MAX_QUADS];
int quad_count = 0;

int next_temp = 1;
int next_label = 1;

const char* get_op_string(OpType op) {
    switch (op) {
        case OP_ADD: return "+";
        case OP_SUB: return "-";
        case OP_MUL: return "*";
        case OP_DIV: return "/";
        case OP_MOD: return "%";
        case OP_EXP: return "^";
        case OP_ASSIGN: return "=";
        case OP_GOTO: return "GOTO";
        case OP_IFGOTO: return "IF_GOTO";
        case OP_IFFALSE: return "IF_FALSE";
        case OP_LABEL: return "LABEL";
        case OP_CALL: return "CALL";
        case OP_PARAM: return "PARAM";
        case OP_RETURN: return "RETURN";
        case OP_LT: return "<";
        case OP_GT: return ">";
        case OP_LTE: return "<=";
        case OP_GTE: return ">=";
        case OP_EQ: return "==";
        case OP_NEQ: return "!=";
        case OP_AND: return "AND";
        case OP_OR: return "OR";
        case OP_NOT: return "NOT";
        case OP_UMINUS: return "UMINUS";
        case OP_INC: return "++";
        case OP_DEC: return "--";
        default: return "UNKNOWN_OP";
    }
}

char* new_temp() {
    char* name = malloc(10);
    snprintf(name, 10, "t%d", next_temp++);
    return name;
}

char* new_label() {
    char* label = malloc(10);
    snprintf(label, 10, "L%d", next_label++);
    return label;
}

void add_quadruple(OpType op, const char* arg1, const char* arg2, const char* result) {
    if (quad_count >= MAX_QUADS) {
        fprintf(stderr, "Error: Too many quadruples!\n");
        exit(1);
    }
    quadruples[quad_count].op = op;
    quadruples[quad_count].arg1 = arg1 ? strdup(arg1) : NULL;
    quadruples[quad_count].arg2 = arg2 ? strdup(arg2) : NULL;
    quadruples[quad_count].result = result ? strdup(result) : NULL;
    quad_count++;
}

void print_quadruples() {
    printf("\n=== Generated Quadruples ===\n");
    for (int i = 0; i < quad_count; i++) {
        printf("[%d] (%s, %s, %s, %s)\n", i,
            get_op_string(quadruples[i].op),
            quadruples[i].arg1 ? quadruples[i].arg1 : "_",
            quadruples[i].arg2 ? quadruples[i].arg2 : "_",
            quadruples[i].result ? quadruples[i].result : "_"
        );
    }
}

void free_quadruples() {
    for (int i = 0; i < quad_count; i++) {
        free(quadruples[i].arg1);
        free(quadruples[i].arg2);
        free(quadruples[i].result);
    }
    quad_count = 0;
}