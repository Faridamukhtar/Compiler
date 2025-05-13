#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "parameter.h"

Parameter* createParameter(const char *name, const char *type) {
    Parameter *param = (Parameter*)malloc(sizeof(Parameter));
    if (!param) return NULL;

    param->name = strdup(name);
    param->type = strdup(type);
    param->next = NULL;
    return param;
}

Parameter* addParameter(Parameter *head, const char *name, const char *type) {
    Parameter *new_param = createParameter(name, type);
    if (!new_param) return head;

    if (!head) {
        return new_param;
    }

    Parameter *current = head;
    while (current->next) {
        current = current->next;
    }
    current->next = new_param;
    return head;
}

void freeParameterList(Parameter *head) {
    while (head) {
        Parameter *temp = head;
        head = head->next;
        free(temp->name);
        free(temp->type);
        free(temp);
    }
}

void printParameterList(const Parameter *head) {
    while (head) {
        printf("Param: Name = %s, Type = %s\n", head->name, head->type);
        head = head->next;
    }
}
