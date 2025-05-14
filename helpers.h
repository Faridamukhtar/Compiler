#ifndef HELPERS_H
#define HELPERS_H

char** split(const char* str, const char* delimiter, int* count);

void free_split_result(char** result, int count);

bool areTypesCompatible(ValueType t1, ValueType t2);

char* concat_with_comma(const char* str1, const char* str2);

const char* typeToString(ValueType type);

#endif // SPLIT_H
