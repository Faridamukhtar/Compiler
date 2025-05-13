#ifndef HELPERS_H
#define HELPERS_H

// Function to split a string based on a delimiter
char** split(const char* str, const char* delimiter, int* count);

// Function to free the memory allocated by the split function
void free_split_result(char** result, int count);

bool areTypesCompatible(ValueType t1, ValueType t2);
#endif // SPLIT_H
