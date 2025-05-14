#include <stdio.h>
#include <string.h>
#include "quadruple.h"
#define IS_VALID(s) ((s) && strcmp((s), "_") != 0 && strlen((s)) > 0)

static const char* clean(const char* s) {
    return (s && strcmp(s, "_") != 0) ? s : "";
}

void convert_quadruples_to_assembly(const char *filename) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        printf("Error opening file %s\n", filename);
        return;
    }

    char last_jump[128] = "";

    for (int i = 0; i < quad_count; ++i) {
        Quadruple q = quadruples[i];
        const char *a1 = q.arg1 ? q.arg1 : "_";
        const char *a2 = q.arg2 ? q.arg2 : "_";
        const char *res = q.result ? q.result : "_";

        switch (q.op) {
            case OP_ASSIGN:
                fprintf(fp, "MOV %s, %s\n", clean(res), clean(a1));
                break;
            case OP_ADD:
                fprintf(fp, "ADD %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_SUB:
                fprintf(fp, "SUB %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_MUL:
                fprintf(fp, "MUL %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_DIV:
                fprintf(fp, "DIV %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_MOD:
                fprintf(fp, "MOD %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_EXP:
                fprintf(fp, "EXP %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_EQ:
                fprintf(fp, "EQ %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_NEQ:
                fprintf(fp, "NEQ %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_LT:
                fprintf(fp, "LT %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_GT:
                fprintf(fp, "GT %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_LTE:
                fprintf(fp, "LTE %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_GTE:
                fprintf(fp, "GTE %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_AND:
                fprintf(fp, "AND %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_OR:
                fprintf(fp, "OR %s, %s, %s\n", clean(res), clean(a1), clean(a2));
                break;
            case OP_NOT:
                fprintf(fp, "NOT %s, %s\n", clean(res), clean(a1));
                break;
            case OP_UMINUS:
                fprintf(fp, "NEG %s, %s\n", clean(res), clean(a1));
                break;
            case OP_INC:
                fprintf(fp, "INC %s\n", clean(res));
                break;
            case OP_DEC:
                fprintf(fp, "DEC %s\n", clean(res));
                break;
            case OP_LABEL:
                if (IS_VALID(res))
                    fprintf(fp, "\n%s:\n", res);
                else
                    fprintf(fp, ";\n");
                break;
            case OP_GOTO:
                if (IS_VALID(res)) {
                    char jump[128];
                    snprintf(jump, sizeof(jump), "JMP %s", res);
                    if (strcmp(jump, last_jump) != 0) {
                        fprintf(fp, "%s\n", jump);
                        strcpy(last_jump, jump);
                    }
                } else {
                    fprintf(fp, ";\n");
                }
                break;
            case OP_IFGOTO:
                if (IS_VALID(res))
                    fprintf(fp, "JNZ %s, %s\n", clean(a1), res);
                else
                    fprintf(fp, ";\n");
                break;
            case OP_IFFALSE:
                if (IS_VALID(res))
                    fprintf(fp, "JZ %s, %s\n", clean(a1), res);
                else
                    fprintf(fp, ";\n");
                break;
            case OP_CALL:
                fprintf(fp, "CALL %s\n", clean(a1));
                if (IS_VALID(res))
                    fprintf(fp, "MOV %s, EAX\n", res);
                break;
            case OP_RETURN:
                if (IS_VALID(a1))
                    fprintf(fp, "MOV EAX, %s\n", a1);
                fprintf(fp, "RET\n");
                break;
            case OP_PARAM:
                if (IS_VALID(a1))
                    fprintf(fp, "PUSH %s\n", a1);
                else
                    fprintf(fp, ";\n");
                break;
            case OP_ITOF:
                fprintf(fp, "ITOF %s, %s\n", clean(res), clean(a1));
                break;
            default:
                fprintf(fp, ";\n");
                break;
        }
    }

    fclose(fp);
}
