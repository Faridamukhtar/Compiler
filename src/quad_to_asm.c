#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// Helper function to trim whitespace
char *trim(char *str) {
    char *end;
    while (isspace((unsigned char)*str)) str++;
    if (*str == 0) return str;
    end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end)) end--;
    end[1] = '\0';
    return str;
}

// Helper function to check if a string is a number
int is_number(const char* str) {
    if (!str) return 0;
    if (*str == '-' || *str == '+') str++;
    while (*str) {
        if (!isdigit(*str)) return 0;
        str++;
    }
    return 1;
}

// Helper function to check if a string is a boolean literal
int is_boolean(const char* str) {
    return str && (strcmp(str, "true") == 0 || strcmp(str, "false") == 0);
}

// Helper function to get boolean value
int get_boolean_value(const char* str) {
    return strcmp(str, "true") == 0;
}

// Helper function to check if a string is a string literal
int is_string_literal(const char* str) {
    return str && str[0] == '"' && str[strlen(str)-1] == '"';
}

// Helper function to check if a variable is already declared
int is_declared(const char* var, char** declared_vars, int var_count) {
    for (int i = 0; i < var_count; i++) {
        if (strcmp(var, declared_vars[i]) == 0) return 1;
    }
    return 0;
}

void convert_quadruples_to_assembly(const char *filename) {
    FILE *quadfile = fopen("quadruples.txt", "r");
    if (!quadfile) {
        printf("Error opening quadruples.txt\n");
        return;
    }
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        printf("Error opening file %s\n", filename);
        fclose(quadfile);
        return;
    }

    char line[512];
    while (fgets(line, sizeof(line), quadfile)) {
        char op[32], arg1[128], arg2[128], result[128];
        int n = sscanf(line, "[%*d] (%31[^,], %127[^,], %127[^,], %127[^)])", op, arg1, arg2, result);
        if (n == 4) {
            char *a1 = trim(arg1);
            char *a2 = trim(arg2);
            char *res = trim(result);
            if (strcmp(op, "=") == 0) {
                fprintf(fp, "mov %s, %s\n", res, a1);
            } else if (strcmp(op, "+") == 0) {
                fprintf(fp, "add %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "-") == 0) {
                fprintf(fp, "sub %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "*") == 0) {
                fprintf(fp, "mul %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "/") == 0) {
                fprintf(fp, "div %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "%") == 0) {
                fprintf(fp, "mod %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "==") == 0) {
                fprintf(fp, "eq %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "!=") == 0) {
                fprintf(fp, "neq %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "<") == 0) {
                fprintf(fp, "lt %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, ">") == 0) {
                fprintf(fp, "gt %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "<=") == 0) {
                fprintf(fp, "lte %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, ">=") == 0) {
                fprintf(fp, "gte %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "AND") == 0) {
                fprintf(fp, "and %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "OR") == 0) {
                fprintf(fp, "or %s, %s, %s\n", res, a1, a2);
            } else if (strcmp(op, "NOT") == 0) {
                fprintf(fp, "not %s, %s\n", res, a1);
            } else if (strcmp(op, "++") == 0) {
                fprintf(fp, "inc %s\n", res);
            } else if (strcmp(op, "--") == 0) {
                fprintf(fp, "dec %s\n", res);
            } else if (strcmp(op, "LABEL") == 0) {
                if (strcmp(res, "_") != 0 && strlen(res) > 0) fprintf(fp, "%s:\n", res);
                else fprintf(fp, ";\n");
            } else if (strcmp(op, "GOTO") == 0) {
                if (strcmp(res, "_") != 0 && strlen(res) > 0) fprintf(fp, "jmp %s\n", res);
                else if (strcmp(a1, "_") != 0 && strlen(a1) > 0) fprintf(fp, "jmp %s\n", a1);
                else fprintf(fp, ";\n");
            } else if (strcmp(op, "IF_GOTO") == 0) {
                if (strcmp(res, "_") != 0 && strlen(res) > 0) fprintf(fp, "jif %s, %s\n", a1, res);
                else fprintf(fp, ";\n");
            } else if (strcmp(op, "CALL") == 0) {
                fprintf(fp, "call %s\n", a1);
                if (strcmp(res, "_") != 0 && strlen(res) > 0) fprintf(fp, "mov %s, eax\n", res);
            } else if (strcmp(op, "RETURN") == 0) {
                if (strcmp(a1, "_") != 0 && strlen(a1) > 0) fprintf(fp, "mov eax, %s\n", a1);
                fprintf(fp, "ret\n");
            } else if (strcmp(op, "PARAM") == 0) {
                if (strcmp(a1, "_") != 0 && strlen(a1) > 0) fprintf(fp, "push %s\n", a1);
                else fprintf(fp, ";\n");
            } else {
                fprintf(fp, "; Unhandled operation: %s\n", op);
            }
        } else {
            fprintf(fp, ";\n");
        }
    }

    fclose(fp);
    fclose(quadfile);
}
