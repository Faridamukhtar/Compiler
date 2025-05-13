;
mov x, 5
mov y, 5
eq t1, x, y
jif t1, L1
jmp L2
L1:
mov x, 0
jmp L3
L2:
mov y, 0
neq t2, x, y
jif t2, L4
jmp L5
L4:
mov z, 0
jmp L6
L5:
L6:
L3:
