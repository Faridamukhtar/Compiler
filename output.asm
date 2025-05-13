section .data
    x dd 0
    y dd 0

section .text
global _start

_start:
    mov dword [C1], 5
    mov dword [C2], true
    mov dword [x], 10
    mov dword [y], 20
    mov dword [z], 30
    mov dword [a], 2.500000
    mov dword [flag], false
    mov dword [y], t2
    mov dword [y], t4
    mov dword [y], t5
    mov dword [y], t7
    mov dword [i], 0
    mov dword [i], t11
    mov dword [x], t12
    mov dword [z], t13
    mov dword [y], t16
    mov dword [y], t18
    mov dword [y], t19
    mov dword [sum], t20
    mov dword [x], t26
    mov dword [flag], t27
    mov eax, 1
    xor ebx, ebx
    int 0x80
