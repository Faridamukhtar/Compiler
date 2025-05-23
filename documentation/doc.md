
#  Intermediate Assembly Language Specification

This document specifies the **pseudo-assembly language** generated by the `convert_quadruples_to_assembly()` function. This intermediate representation is used in compiler backends to bridge semantic IR and machine code generation.

---

##  General Syntax

Each instruction is written in the form:

```
INSTRUCTION [RESULT], [ARG1], [ARG2]
```

- **RESULT** is the destination (often a temporary like `t1`)
- **ARG1**, **ARG2** are inputs
- Missing operands (e.g., `_`) are **ignored in output**

---

##  Instruction Set

###  Assignment

#### `OP_ASSIGN`

```
MOV result, arg1
```

Assign value from `arg1` to `result`.

**Examples**:
```asm
MOV x, 5
MOV flag, true
MOV t1, y
```

---

###  Arithmetic Operations

```
OP result, arg1, arg2
```

| OpType   | Instruction | Meaning             | Example              |
|----------|-------------|---------------------|----------------------|
| OP_ADD   | ADD         | Addition             | `ADD t1, x, y`       |
| OP_SUB   | SUB         | Subtraction          | `SUB t2, x, 1`       |
| OP_MUL   | MUL         | Multiplication       | `MUL t3, x, 4`       |
| OP_DIV   | DIV         | Integer Division     | `DIV t4, x, y`       |
| OP_MOD   | MOD         | Modulus              | `MOD t5, x, 2`       |
| OP_EXP   | EXP         | Exponentiation       | `EXP t6, 2, 3`       |

---

###  Comparison Operators

```
OP result, arg1, arg2
```

| OpType   | Instruction | Meaning              | Example              |
|----------|-------------|----------------------|----------------------|
| OP_EQ    | EQ          | Equal                | `EQ t1, x, 5`        |
| OP_NEQ   | NEQ         | Not Equal            | `NEQ t2, y, 0`       |
| OP_LT    | LT          | Less Than            | `LT t3, x, y`        |
| OP_GT    | GT          | Greater Than         | `GT t4, y, x`        |
| OP_LTE   | LTE         | Less Than or Equal   | `LTE t5, x, 10`      |
| OP_GTE   | GTE         | Greater Than or Equal| `GTE t6, y, 20`      |

---

###  Logical Operators

| OpType   | Instruction | Meaning           | Syntax                        |
|----------|-------------|-------------------|--------------------------------|
| OP_AND   | AND         | Logical AND       | `AND t1, a, b`                |
| OP_OR    | OR          | Logical OR        | `OR t2, x, y`                 |
| OP_NOT   | NOT         | Logical NOT       | `NOT t3, flag`                |

---

###  Unary Arithmetic

| OpType     | Instruction | Meaning        | Example              |
|------------|-------------|----------------|----------------------|
| OP_UMINUS  | NEG         | Unary negation | `NEG t1, a`          |
| OP_INC     | INC         | Increment      | `INC x`              |
| OP_DEC     | DEC         | Decrement      | `DEC i`              |

---

##  Control Flow

###  Labels

```
LABEL_NAME:
```

Marks a jump target.

**Example**:
```asm
L1:
```

---

###  Jumps

| OpType      | Instruction | Condition     | Example              |
|-------------|-------------|---------------|----------------------|
| OP_GOTO     | JMP         | Unconditional | `JMP L2`             |
| OP_IFGOTO   | JNZ         | If true       | `JNZ t1, L1`         |
| OP_IFFALSE  | JZ          | If false      | `JZ flag, END`       |

---

##  Function Handling

### `OP_CALL`

```
CALL function
MOV result, EAX
```

Call a function and retrieve result.

**Example**:
```asm
CALL add
MOV t1, EAX
```

---

### `OP_RETURN`

Return from a function, optionally with value.

**Syntax**:
```asm
MOV EAX, result   ; if returning value
RET
```

**Example**:
```asm
MOV EAX, sum
RET
```

---

### `OP_PARAM`

Push argument before a call.

**Example**:
```asm
PUSH x
```

---

##  Example Program

```asm
MOV x, 5
MOV y, 10
ADD t1, x, y
EQ t2, t1, 15
JNZ t2, L1
JMP L2

L1:
CALL sum
MOV t3, EAX
RET

L2:
RET
```

---

##  Notes

- Placeholder `_` means "no operand" and is skipped.
- Temporaries like `t1`, `t2` are compiler-generated.
- `EAX` holds function return values.

---

##  Original High-Level Language (Source Language)

This intermediate assembly language is generated from a custom C-like language with the following key features:

###  Data Types
- `int`: integer values (e.g., `int x = 5;`)
- `float`: floating-point numbers (e.g., `float y = 3.14;`)
- `bool`: boolean values (`true` or `false`)
- `char`: single characters (e.g., `'A'`)
- `string`: text in double quotes (e.g., `"Hello"`)
- `void`: functions that return no value

###  Operators

#### Arithmetic:
- `+`, `-`, `*`, `/`, `%`, `^`

#### Comparison:
- `==`, `!=`, `<`, `>`, `<=`, `>=`

#### Logical:
- `and`, `or`, `not`

#### Assignment:
- `=`

#### Increment/Decrement:
- `++`, `--`

###  Control Flow

#### Conditionals:
```c
if (x > y) { ... }
else if (x == y) { ... }
else { ... }
```

#### Loops:
```c
for (int i = 0; i < 10; i++) { ... }
while (x > 0) { ... }
repeat { ... } until (x >= MAX);
```

#### Switch:
```c
switch (x) {
  case 1: ...; break;
  case 2: ...; break;
  default: ...;
}
```

#### Loop Control:
- `break`
- `continue`

###  Functions
```c
function int add(int a, int b) {
    return a + b;
}

int result = add(5, 10);
```

###  Input/Output
```c
print("Hello, World!");
```

###  Comments
```c
// Single-line
/* Multi-line */
```

This source language is parsed into quadruples, which are then lowered into the intermediate assembly representation described above.

---

##  From High-Level Language to Quadruples: Overview

This section explains how a simple high-level programming language is translated into intermediate code using **quadruples**, before being converted into **pseudo-assembly**.

---

##  High-Level Language Features

The source language is similar to C, supporting variables, functions, control flow, and expressions. Below is a breakdown of features and how they translate into quadruples.

---

###  Variables and Constants

**High-Level:**
```c
int x = 5;
float y = 3.14;
bool flag = true;
```

**Quadruples:**
```
(=, 5, _, x)
(=, 3.14, _, y)
(=, true, _, flag)
```

---

###  Arithmetic Expressions

**High-Level:**
```c
int sum = a + b;
```

**Quadruples:**
```
(+, a, b, t1)
(=, t1, _, sum)
```

---

###  Comparisons

**High-Level:**
```c
if (x < y) { ... }
```

**Quadruples:**
```
(<, x, y, t1)
(IF_GOTO, t1, _, Label_True)
```

---

###  Logical Operations

**High-Level:**
```c
if (not flag) { ... }
```

**Quadruples:**
```
(NOT, flag, _, t1)
(IF_GOTO, t1, _, Label_True)
```

---

###  Loops

**High-Level (while):**
```c
while (i < 10) {
    i = i + 1;
}
```

**Quadruples:**
```
LABEL, _, _, L1
(<, i, 10, t1)
(IFFALSE, t1, _, L2)
(+, i, 1, t2)
(=, t2, _, i)
(GOTO, _, _, L1)
LABEL, _, _, L2
```

---

###  Conditionals

**High-Level:**
```c
if (x == 5) {
  ...
} else {
  ...
}
```

**Quadruples:**
```
(==, x, 5, t1)
(IFFALSE, t1, _, ELSE)
...    ; if-body
(GOTO, _, _, END)
LABEL, _, _, ELSE
...    ; else-body
LABEL, _, _, END
```

---

###  Functions

**High-Level:**
```c
function int add(int a, int b) {
  return a + b;
}
int result = add(5, 10);
```

**Quadruples:**
```
LABEL, _, _, add
(PARAM, a, _, _)
(PARAM, b, _, _)
(+, a, b, t1)
(RETURN, t1, _, _)

(PARAM, 5, _, _)
(PARAM, 10, _, _)
(CALL, add, _, t2)
(=, t2, _, result)
```

---

###  Input/Output

**High-Level:**
```c
print("Hello");
```

**Note:**  
Quadruples for I/O depend on implementation  may use pseudo-ops like `(PRINT, "Hello", _, _)`.

---

##  Summary

| High-Level Code           | Quadruples Equivalent                     |
|---------------------------|-------------------------------------------|
| `x = 5;`                  | `(=, 5, _, x)`                             |
| `sum = a + b;`            | `(+ , a, b, t1)`  `(=, t1, _, sum)`      |
| `if (x == y)`             | `(==, x, y, t1)`  `(IF_GOTO, t1, _, L1)` |
| `while (i < 10)`          | loop: `(LT, i, 10, t1)` + jumps           |
| `return x`                | `(RETURN, x, _, _)`                       |
| `call foo(a, b)`          | `(PARAM, a)`, `(PARAM, b)`, `(CALL, foo)`|

Quadruples are a clean, structured way to represent semantics  ready to be lowered into assembly.

