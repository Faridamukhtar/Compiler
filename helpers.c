#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "symbol_table.h"
#include "helpers.h"

char** split(const char* str, const char* delimiter, int* count) {
    char* str_copy = strdup(str);
    if (!str_copy) {
        return NULL;
    }

    char** result = malloc(sizeof(char*) * 10);
    if (!result) {
        free(str_copy);
        return NULL;
    }

    int index = 0;
    char* token = strtok(str_copy, delimiter);

    // Loop through the string and split it based on the delimiter
    while (token != NULL) {
        result[index] = strdup(token);
        if (!result[index]) {
            for (int i = 0; i < index; i++) {
                free(result[i]);
            }
            free(result);
            free(str_copy);
            return NULL;
        }
        index++;

        if (index % 10 == 0) {
            result = realloc(result, sizeof(char*) * (index + 10));
            if (!result) {
                for (int i = 0; i < index; i++) {
                    free(result[i]);
                }
                free(str_copy);
                return NULL;
            }
        }

        token = strtok(NULL, delimiter);
    }

    *count = index;
    free(str_copy);
    return result;
}

void free_split_result(char** result, int count) {
    for (int i = 0; i < count; i++) {
        free(result[i]);
    }
    free(result);
}


bool areTypesCompatible(ValueType t1, ValueType t2) {
    if ((t1 == INT_TYPE || t1 == FLOAT_TYPE) && (t2 == INT_TYPE || t2 == FLOAT_TYPE)) return true;
    return t1 == t2;
}


char* concat_with_comma(const char* str1, const char* str2) {
    if (!str1 || !str2) {
        return NULL;
    }

    size_t len1 = strlen(str1);
    size_t len2 = strlen(str2);
    size_t total_len = len1 + len2 + 2;

    char* result = (char*)malloc(total_len);
    if (!result) {
        return NULL;
    }

    strcpy(result, str1);
    strcat(result, ",");
    strcat(result, str2);

    return result;
}

const char* typeToString(ValueType type) {
    switch (type) {
        case INT_TYPE: return "int";
        case FLOAT_TYPE: return "float";
        case STRING_TYPE: return "string";
        case BOOL_TYPE: return "bool";
        case CHAR_TYPE: return "char";
        case VOID_TYPE: return "void";
        default: return "unknown";
    }
}
