#ifndef PARAMETER_H
#define PARAMETER_H

#include <stdbool.h>

typedef struct Parameter {
    char *name;
    char *type;
    struct Parameter *next;
} Parameter;

Parameter* createParameter(const char *name, const char *type);
Parameter* addParameter(Parameter *head, Parameter *param);
void freeParameterList(Parameter *head);
void printParameterList(const Parameter *head);
char* parameterListToString(const Parameter* head);
bool compareParameters(Parameter* declared, Parameter* passed);


#endif // PARAMETER_H
