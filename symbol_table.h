#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "parameter.h"

typedef enum {
    INT_TYPE,
    FLOAT_TYPE,
    STRING_TYPE,
    BOOL_TYPE,
    CHAR_TYPE,
    VOID_TYPE
} ValueType;

typedef union {
    char *sVal;
    int iVal;
    float fVal;
    char cVal;
    bool bVal;
} Value;

typedef struct expression {
    int type;
    Value value;
    char *temp_var;
} expr;

typedef struct SymbolTable {
    char *identifierName; // esm el fn 
    ValueType type; //int
    bool isConst; 
    int isInitialized;
    int isUsed;
    bool isFunction;
    Value value;
    Parameter *params;
    struct SymbolTable *next;
} SymbolTableEntry;

typedef struct Scope {
    SymbolTableEntry *symbols;
    struct Scope *parent;
} Scope;

extern Scope *currentScope;

void initSymbolTable();

void enterScope();
void exitScope();

// Tracking Scopes
void removeScope();
void addScope();

void *addSymbol(char *name, char *type, bool isIntialized , Value value , bool isConst , bool isFunction, Parameter *params); // add intialize here
SymbolTableEntry *lookupSymbol(char *name);

int updateSymbolValue(char *name, Value newValue);
bool isSymbolDeclaredInCurrentScope(char *name);

void writeSymbolTableOfAllScopesToFile(FILE *file);
void clearSymbolTables(Scope *scope);

ValueType mapStringToValueType(const char *typeStr);
const char *valueTypeToString(ValueType type); // optional, for debugging/printing

void handlePostfixDec(char *identifier);

// Function to handle prefix increment (INC IDENTIFIER)
void handlePrefixInc(char *identifier);
void addParamsToSymbolTable(const Parameter* head);
void handleFunctionCall(char *fnName, Value *args, int argCount);

// void reportUnusedVariables();
// void reportUninitializedVariables();

void checkUnclosedScopes(int yylineno);
void reportUnusedVariables();

#endif