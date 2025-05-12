#ifndef ERROR_HANDLER_H
#define ERROR_HANDLER_H

// Type of error (semantic or syntax)
typedef enum {
    SYNTAX_ERROR,
    SEMANTIC_ERROR
} ErrorType;

// Function declarations
void report_error(ErrorType type, const char *message, int line);
void print_all_errors();
int get_error_count();

#endif
