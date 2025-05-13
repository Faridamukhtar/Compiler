#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

typedef enum {
    INT_TYPE,
    FLOAT_TYPE,
    STRING_TYPE,
    BOOL_TYPE,
    CHAR_TYPE
} ValueType;

typedef union {
    char *sVal;
    int iVal;
    float fVal;
    char cVal;
    bool bVal;
} Value;

typedef struct Parameter {
    char *name;
    char *type;
    struct Parameter *next;
} Parameter;


typedef struct expression {
    ValueType type; //int
    Value value;

} expr;

typedef struct SymbolTable {
    char *identifierName; // esm el fn 
    ValueType type; //int
    char *returnType; // We will only have return type if the type was fn  
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

void *addSymbol(char *name, char *type, bool isIntialized , Value value , bool isConst , bool isFunction, Parameter *params, char *returnType); // add intialize here
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

#endif