#ifndef QUADRUPLE_H
#define QUADRUPLE_H

#define MAX_QUADS 1000

// This header is used by both the IR and the assembly generator

typedef enum {
    OP_ADD,
    OP_SUB,
    OP_MUL,
    OP_DIV,
    OP_MOD,
    OP_EXP,
    OP_ASSIGN,
    OP_GOTO,
    OP_IFGOTO,
    OP_IFFALSE,
    OP_LABEL,
    OP_CALL,
    OP_PARAM,
    OP_RETURN,
    OP_LT,
    OP_GT,
    OP_LTE,
    OP_GTE,
    OP_EQ,
    OP_NEQ,
    OP_AND,
    OP_OR,
    OP_NOT,
    OP_UMINUS,
    OP_INC,
    OP_DEC,
    OP_ITOF,
    OP_FTOI,
    OP_CTOI,
    OP_ITOB
} OpType;

typedef struct {
    OpType op;
    char *arg1;
    char *arg2;
    char *result;
} Quadruple;

extern Quadruple quadruples[MAX_QUADS];
extern int quad_count;

void add_quadruple(OpType op, const char *arg1, const char *arg2, const char *result);
char *new_temp();
char *new_label();
void print_quadruples();
void free_quadruples();
const char* get_op_string(OpType op);

#endif