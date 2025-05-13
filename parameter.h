#ifndef PARAMETER_H
#define PARAMETER_H

typedef struct Parameter {
    char *name;
    char *type;
    struct Parameter *next;
} Parameter;

Parameter* createParameter(const char *name, const char *type);
Parameter* addParameter(Parameter *head, const char *name, const char *type);
void freeParameterList(Parameter *head);
void printParameterList(const Parameter *head);

#endif // PARAMETER_H
