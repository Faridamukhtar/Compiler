#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "error_handler.h"

#define MAX_ERRORS 100

typedef struct {
    ErrorType type;
    char message[256];
    int line;
} Error;

static Error errors[MAX_ERRORS];
static int error_count = 0;

void report_error(ErrorType type, const char *message, int line) {
    if (error_count >= MAX_ERRORS) return;
    errors[error_count].type = type;
    strncpy(errors[error_count].message, message, 255);
    errors[error_count].line = line;
    error_count++;
}

void print_all_errors() {
    for (int i = 0; i < error_count; i++) {
        const char *type_str = (errors[i].type == SYNTAX_ERROR) ? "Syntax" : "Semantic";
        printf("[%s Error] Line %d: %s\n", type_str, errors[i].line, errors[i].message);
    }
}

int get_error_count() {
    return error_count;
}
