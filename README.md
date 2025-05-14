
# Compilers-Project

A dark-themed graphical compiler frontend built with **PyQt5**, featuring syntax and semantic analysis, quadruple code generation, and export capabilities.

---

## How to Run the Project

### 1. Install Dependencies

#### Frontend (Python GUI)

Make sure Python 3 is installed, then install the required packages:

```bash
pip install PyQt5 QScintilla
```

#### Backend (Compiler)

Install development tools:

```bash
sudo apt update
sudo apt install build-essential bison flex
```

---

### 2. Build the Compiler

```bash
make
```

This generates the `./compiler` binary used by the GUI.

---

### 3. Run the GUI

```bash
python3 gui.py
```

This will launch the dark-themed interface.

---

### 4. Export Output Files

After clicking **Compile**, you can click **Export** to:

* Save:

  * `input_code.txt`
  * `symbol_table.txt`
  * `quadruples.txt`
  * `output.asm`
  * `syntax_errors.txt`
  * `semantic_errors.txt`
  * `warnings.txt`

* All files are saved to an `outputs/` folder.

---

## Features

* Dark-themed, modern interface
* Syntax and semantic error highlighting
* Quadruple code generation
* One-click export of all results

## Screenshot 
### Error
<img width="993" alt="Screenshot 2025-05-14 at 12 22 20 PM" src="https://github.com/user-attachments/assets/470da2f6-ae8b-4625-bbca-fe2eec2f5016" />

### Compiled Assembly-like Intermediate Language
<img width="992" alt="Screenshot 2025-05-14 at 12 22 08 PM" src="https://github.com/user-attachments/assets/9528e3a6-a096-4220-b3f3-19b7252c7c4d" />

