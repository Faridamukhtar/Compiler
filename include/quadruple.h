#ifndef QUADRUPLE_H
#define QUADRUPLE_H

#define MAX_QUADS 1000

typedef struct {
    char *op;
    char *arg1;
    char *arg2;
    char *result;
} Quadruple;

extern Quadruple quad_table[MAX_QUADS];
extern int quad_count;

void emit(const char *op, const char *arg1, const char *arg2, const char *result);
char *new_temp();
char *new_label();
void print_quadruples();
void free_quadruples();

#endif
