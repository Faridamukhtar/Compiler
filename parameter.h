#ifndef PARAMETER_H
#define PARAMETER_H

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


#endif // PARAMETER_H
