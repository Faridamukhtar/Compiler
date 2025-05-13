#include <stdio.h>
#include "quadruple.h"

void convert_quadruples_to_assembly(const char *filename) {
    FILE *fp = fopen(filename, "w");
    if (!fp) {
        printf("Error opening file %s\n", filename);
        return;
    }

    // Write a simple header
    fprintf(fp, "section .data\n    x dd 0\n    y dd 0\n\nsection .text\nglobal _start\n\n_start:\n");

    // Convert each quadruple (expand for all your opcodes as needed)
    for (int i = 0; i < quad_count; i++) {
        Quadruple *q = &quadruples[i];
        if (q->op == OP_ASSIGN) {
            fprintf(fp, "    mov dword [%s], %s\n", q->result, q->arg1);
        }
        // Add more cases for other opcodes as needed
    }

    // Exit
    fprintf(fp, "    mov eax, 1\n    xor ebx, ebx\n    int 0x80\n");
    fclose(fp);
} 