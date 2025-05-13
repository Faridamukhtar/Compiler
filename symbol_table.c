#include "symbol_table.h"
#include "error_handler.h"

Scope *currentScope = NULL;
Scope *allScopes[1000];     
int scopeCount = 0;    
int scope_depth = 0;  // Add scope depth tracking


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

void addScope()
{
    scope_depth++;  // Increment scope depth
}


void removeScope()
{
    scope_depth--;  // Decrement scope depth
}

void exitScope() {
    currentScope = currentScope->parent;
}

void *addSymbol(char *name, char *type, bool isIntialized, Value value, bool isConst, bool isFunction, Parameter *params) {
    if (currentScope == NULL) {
        initSymbolTable();
    }

    if (name == NULL || type == NULL) {
        printf("Error: Invalid parameters missing name\n");
        return NULL;
    }

    if (isSymbolDeclaredInCurrentScope(name)) {
        printf("Error: Identifier '%s' is already defined in the current scope\n", name);
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
        return -1;
    }
    if (symbol->isConst && symbol->isInitialized) {
        printf("Error: Cannot update value of constant symbol '%s'.\n", name);
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

            if (symbol->isInitialized && symbol->isFunction ==false) {
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

    fprintf(stderr, "Unknown type string: '%s'\n", typeStr);
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
    const Parameter* current = head;

    while (current != NULL) {
        Value defaultValue;

        addSymbol(
            current->name,
            current->type,
            false,          
            defaultValue,   
            false,          
            false,          
            NULL            
        );

        current = current->next;
    }
}

void handleFunctionCall(char *fnName, Value *args, int argCount) {

    SymbolTableEntry *fnEntry = lookupSymbol(fnName);

    if (fnEntry == NULL) {
        fprintf(stderr, "Error: Function '%s' is not declared.\n", fnName);
        exit(EXIT_FAILURE);
    }

    if (!fnEntry->isFunction) {
        fprintf(stderr, "Error: '%s' is not a function.\n", fnName);
        exit(EXIT_FAILURE);
    }

    printf("Function '%s' found successfully!\n", fnName);

    // (Next step: Check parameters & update the params --> re-enter the scope)
}


void checkUnclosedScopes(int yylineno) 
{
    if (scope_depth > 0) {
        report_error(SYNTAX_ERROR, "Unclosed scope(s) at end of file", yylineno);

    }
    else if (scope_depth < 0) {
        report_error(SYNTAX_ERROR, "Scope Mismatch ", yylineno);
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
