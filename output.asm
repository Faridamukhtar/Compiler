section .data
    x dd 0
    y dd 0

section .text
global _start

_start:
    mov dword [x], 5
    mov eax, 1
    xor ebx, ebx
    int 0x80
