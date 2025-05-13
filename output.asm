section .data
    x dd 0
    y dd 0

section .text
global _start

_start:
    mov dword [x], 5
    mov dword [y], 5
    mov dword [z], 0
    mov dword [t], false
    mov dword [c], true
    mov dword [m], ""mimo""
    mov dword [m], ""zozi""
    mov dword [x], 0
    mov dword [y], 0
    mov dword [z], 0
    mov dword [i], 0
    mov dword [x], 5
    mov dword [y], 6
    mov dword [x], 5
    mov dword [y], 6
    mov dword [x], 5
    mov dword [y], 6
    mov dword [x], t7
    mov dword [x], 5
    mov dword [y], 6
    mov dword [z], 7
    mov eax, 1
    xor ebx, ebx
    int 0x80
