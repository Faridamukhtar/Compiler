#include "symbol_table.h"
#include "error_handler.h"

extern int prev_valid_line;

Scope *currentScope = NULL;
Scope *allScopes[1000];     
int scopeCount = 0;    


void initSymbolTable() {
    if (currentScope == NULL) {
        currentScope = (Scope *)malloc(sizeof(Scope));
        currentScope->symbols = NULL;
        currentScope->parent = NULL;

        allScopes[scopeCount] = currentScope;
        scopeCount++;
    }
}

void enterScope() {
    Scope *newScope = (Scope *)malloc(sizeof(Scope));
    newScope->symbols = NULL;
    newScope->parent = currentScope;
    currentScope = newScope;

    allScopes[scopeCount] = newScope;
    scopeCount++;
}

void exitScope() {
    currentScope = currentScope->parent;  
}

void *addSymbol(char *name, char *type, bool isIntialized, Value value, bool isConst, bool isFunction, Parameter *params) {
    if (currentScope == NULL) {
        initSymbolTable();
    }

    if (name == NULL || type == NULL) {
        report_error(SEMANTIC_ERROR, "Invalid Parameters", prev_valid_line);
        fprintf(stderr, "Semantic Error (line %d): Symbol name or type is NULL.\n", prev_valid_line);
        return NULL;
    }

    if (isSymbolDeclaredInCurrentScope(name)) {
        report_error(SEMANTIC_ERROR, "Variable Redeclaration", prev_valid_line);
        fprintf(stderr, "Semantic Error (line %d): Identifier '%s' is already defined in the current scope.\n", prev_valid_line, name);
        return NULL;
    }


    SymbolTableEntry *newEntry = (SymbolTableEntry *)malloc(sizeof(SymbolTableEntry));
    if (newEntry == NULL) {
        printf("Error: Memory allocation failed\n");
        return NULL;
    }

    newEntry->identifierName = strdup(name);
    newEntry->type = mapStringToValueType(type);
    newEntry->isConst = isConst;
    newEntry->isInitialized = isIntialized; 
    newEntry->isUsed = false;
    newEntry->isFunction = isFunction;
    newEntry->params = params;
    newEntry->value = value;
    newEntry->next = NULL;

    // Add to current scope
    if (currentScope->symbols == NULL) {
        currentScope->symbols = newEntry;
    } else {
        SymbolTableEntry *temp = currentScope->symbols;
        while (temp->next != NULL) {
            temp = temp->next;
        }
        temp->next = newEntry;
    }

    // printf("type %s , name %s\n", type, name);

    return newEntry;
}

SymbolTableEntry *lookupSymbol(char *name) {
    Scope *scope = currentScope;
    while (scope != NULL) {
        SymbolTableEntry *symbol = scope->symbols;
        while (symbol != NULL) {
            if (strcmp(symbol->identifierName, name) == 0) {
                return symbol;
            }
            symbol = symbol->next;
        }
        scope = scope->parent;
    }
    return NULL;
}

int updateSymbolValue(char *name, Value newValue) {
    SymbolTableEntry *symbol = lookupSymbol(name);
    if (symbol == NULL) {
        report_error(SEMANTIC_ERROR, "Undeclared Variable", prev_valid_line);
        fprintf(stderr, "Semantic Error (line %d): Variable '%s' is not declared.\n", prev_valid_line, name);
        return -1;
    }
    if (symbol->isConst && symbol->isInitialized) {
        report_error(SEMANTIC_ERROR, "Constant Reassignment", prev_valid_line);
        fprintf(stderr, "Semantic Error (line %d): Cannot update value of constant symbol '%s'.\n", prev_valid_line, name);
        return 0;
    }
    symbol->value = newValue;
    symbol->isInitialized = 1;
    return 0;
}

bool isSymbolDeclaredInCurrentScope(char *name) {
    SymbolTableEntry *symbol = currentScope->symbols;
    while (symbol != NULL) {
        if (strcmp(symbol->identifierName, name) == 0) {
            return true;
        }
        symbol = symbol->next;
    }
    return false;
}

void writeSymbolTableOfAllScopesToFile(FILE *file) {
    for (int i = 0; i < scopeCount; i++) {
        Scope *scope = allScopes[i];
        fprintf(file, "=== Scope Level: %d ===\n", i);

        SymbolTableEntry *symbol = scope->symbols;
        while (symbol != NULL) {
            char valueStr[256] = "N/A";

            if (symbol->isInitialized && symbol->isFunction == false) {
                switch (symbol->type) {
                    case INT_TYPE:
                        sprintf(valueStr, "%d", symbol->value.iVal);
                        break;
                    case FLOAT_TYPE:
                        sprintf(valueStr, "%f", symbol->value.fVal);
                        break;
                    case STRING_TYPE:
                        sprintf(valueStr, "\"%s\"", symbol->value.sVal);
                        break;
                    case BOOL_TYPE:
                        sprintf(valueStr, "%s", symbol->value.bVal ? "true" : "false");
                        break;
                    case CHAR_TYPE:
                        sprintf(valueStr, "'%c'", symbol->value.cVal);
                        break;
                    default:
                        strcpy(valueStr, "unknown");
                }
            }

            fprintf(file,
                "Name: %s, Type: %s (%d), Value: %s, Const: %d, Initialized: %d, Used: %d, IsFunction: %d, Params: %s\n",
                symbol->identifierName,
                valueTypeToString(symbol->type),
                symbol->type,
                valueStr,
                symbol->isConst,
                symbol->isInitialized,
                symbol->isUsed,
                symbol->isFunction,
                parameterListToString(symbol->params)
            );



            symbol = symbol->next;
        }

        fprintf(file, "\n");
    }
}

void clearSymbolTables(Scope *scope) {
    if (scope == NULL) return;
    SymbolTableEntry *symbol = scope->symbols;
    while (symbol != NULL) {
        SymbolTableEntry *temp = symbol;
        symbol = symbol->next;
        free(temp->identifierName);
        free(temp);
    }
    if (scope->parent) {
        clearSymbolTables(scope->parent);
    }
    free(scope);
}

ValueType mapStringToValueType(const char *typeStr) {
    if (strcmp(typeStr, "int") == 0) return INT_TYPE;
    if (strcmp(typeStr, "float") == 0) return FLOAT_TYPE;
    if (strcmp(typeStr, "string") == 0) return STRING_TYPE;
    if (strcmp(typeStr, "bool") == 0) return BOOL_TYPE;
    if (strcmp(typeStr, "char") == 0) return CHAR_TYPE;
    if (strcmp(typeStr, "void") == 0) return VOID_TYPE;

    report_error(SEMANTIC_ERROR, "Unknown Type", prev_valid_line);
    fprintf(stderr, "Semantic Error (line %d): Unknown type string '%s'.\n", prev_valid_line, typeStr);
    exit(EXIT_FAILURE);
}

const char *valueTypeToString(ValueType type) {
    switch (type) {
        case INT_TYPE: return "int";
        case FLOAT_TYPE: return "float";
        case STRING_TYPE: return "string";
        case BOOL_TYPE: return "bool";
        case CHAR_TYPE: return "char";
        default: return "void";
    }
}

void handlePostfixDec(char *identifier) {
    SymbolTableEntry *entry = lookupSymbol(identifier);
    if (!entry) {
        // printf("Error: Symbol '%s' not declared in the current scope.\n", identifier);
        return;
    }

    // Decrement the symbol value
    if (entry->type == INT_TYPE) {
        entry->value.iVal -= 1;
    } else if (entry->type == FLOAT_TYPE) {
        entry->value.fVal -= 1;
    } else {
        printf("Error: DEC operation is not supported for type '%s'.\n", valueTypeToString(entry->type));
        return;
    }

    // Update symbol value in the symbol table
    updateSymbolValue(identifier, entry->value);
}

void handlePrefixInc(char *identifier) {
    SymbolTableEntry *entry = lookupSymbol(identifier);
    if (!entry) {
        // printf("Error: Symbol '%s' not declared in the current scope.\n", identifier);
        return;
    }

    // Increment the symbol value
    if (entry->type == INT_TYPE) {
        entry->value.iVal += 1;
    } else if (entry->type == FLOAT_TYPE) {
        entry->value.fVal += 1;
    } else {
        printf("Error: INC operation is not supported for type '%s'.\n", valueTypeToString(entry->type));
        return;
    }

    // Update symbol value in the symbol table
    updateSymbolValue(identifier, entry->value);
}

void addParamsToSymbolTable(const Parameter* head) {
    const Parameter* param = head;
    while (param) {
        if (!param->name || !param->type) {
            fprintf(stderr, "Error: Invalid parameter with missing name or type\n");
            return;
        }

        if (isSymbolDeclaredInCurrentScope(param->name)) {
            fprintf(stderr, "Semantic Error: Parameter '%s' already declared in this scope.\n", param->name);
        } else {
            Value val;
            addSymbol(param->name, param->type, true, val, false, false, NULL);
        }

        param = param->next;
    }
}


void reportUnusedVariables() {
    for (int i = 0; i < scopeCount; i++) {
        Scope *scope = allScopes[i];
        SymbolTableEntry *symbol = scope->symbols;
        while (symbol != NULL) {
            if (!symbol->isUsed && !symbol->isFunction) {
                printf("Warning: Variable '%s' declared in scope %d but never used.\n", symbol->identifierName, i);
            }
            symbol = symbol->next;
        }
    }
}
