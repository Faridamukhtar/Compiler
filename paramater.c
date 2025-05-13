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

Parameter* addParameter(Parameter *head, Parameter *param) {
    if (!param) return head;

    if (!head) {
        return param;
    }

    Parameter *current = head;
    while (current->next) {
        current = current->next;
    }
    current->next = param;
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

char* parameterListToString(const Parameter* head) {
    static char buffer[1024];
    buffer[0] = '\0';

    while (head) {
        strcat(buffer, head->type);
        strcat(buffer, " ");
        strcat(buffer, head->name);
        if (head->next) strcat(buffer, ", ");
        head = head->next;
    }

    if (strlen(buffer) == 0) {
        strcpy(buffer, "N/A");
    }

    return buffer;
}

