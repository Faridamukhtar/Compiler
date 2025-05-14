import sys
import subprocess
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QPushButton,
    QTextEdit, QHBoxLayout, QFileDialog, QLabel, QTabWidget, QMessageBox
)
from PyQt5.QtGui import QFont
from PyQt5.Qsci import QsciScintilla, QsciLexerCPP
from PyQt5.QtGui import QFont, QColor
import os

class CompilerGUI(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Compiler Frontend")
        self.resize(1000, 700)

        layout = QVBoxLayout()

        # Code Editor
        self.editor = QsciScintilla()
        self.editor.setUtf8(True)
        lexer = QsciLexerCPP()
        lexer.setDefaultFont(QFont("Courier", 10))
        self.editor.setLexer(lexer)
        self.editor.setFont(QFont("Courier", 10))
        self.editor.setMarginLineNumbers(1, True)
        self.editor.setMarginsForegroundColor(QColor("gray"))
        self.editor.setMarginWidth(1, "0000")
        layout.addWidget(QLabel("Input Code:"))
        layout.addWidget(self.editor)

        # Buttons
        buttonLayout = QHBoxLayout()
        self.compileButton = QPushButton("Compile")
        self.resetButton = QPushButton("Reset")
        self.importButton = QPushButton("Import")
        self.exportButton = QPushButton("Export")

        buttonLayout.addWidget(self.compileButton)
        buttonLayout.addWidget(self.resetButton)
        buttonLayout.addWidget(self.importButton)
        buttonLayout.addWidget(self.exportButton)
        layout.addLayout(buttonLayout)

        # Output Tabs
        self.tabs = QTabWidget()
        self.symbolTab = QTextEdit()
        self.quadTab = QTextEdit()
        self.errorTab = QTextEdit()
        self.warningTab = QTextEdit()
        self.asmTab = QTextEdit()

        for tab in [self.symbolTab, self.quadTab, self.errorTab, self.warningTab, self.asmTab]:
            tab.setFont(QFont("Courier", 10))
            tab.setReadOnly(True)

        self.tabs.addTab(self.symbolTab, "Symbol Table")
        self.tabs.addTab(self.quadTab, "Quadruples")
        self.tabs.addTab(self.errorTab, "Errors")
        self.tabs.addTab(self.warningTab, "Warnings")
        self.tabs.addTab(self.asmTab, "Assembly")
        layout.addWidget(self.tabs)

        self.setLayout(layout)

        # Button Connections
        self.compileButton.clicked.connect(self.compile_code)
        self.resetButton.clicked.connect(self.reset_editor)
        self.importButton.clicked.connect(self.import_code)
        self.exportButton.clicked.connect(self.export_code)

    def compile_code(self):
        input_code = self.editor.text()
        with open("test/input.txt", "w") as f:
            f.write(input_code)

        try:
            with open("test/input.txt", "r") as f:
                input_data = f.read()
            result = subprocess.run(["./compiler"], input=input_data, capture_output=True, text=True)
        except Exception as e:
            QMessageBox.critical(self, "Execution Error", str(e))
            return

        self.errorTab.setText("")
        self.warningTab.setText("")

        # Handle stdout
        if result.stdout:
            for line in result.stdout.splitlines():
                if "Semantic Error" in line or "Syntax Error" in line:
                    self.errorTab.append(line)
                elif "Warning" in line:
                    self.warningTab.append(line)

        # Handle stderr
        if result.stderr:
            self.errorTab.append("--- STDERR ---")
            self.errorTab.append(result.stderr)

        self.load_output_files()

    def reset_editor(self):
        self.editor.setText("")
        for tab in [self.symbolTab, self.quadTab, self.errorTab, self.warningTab, self.asmTab]:
            tab.clear()

    def import_code(self):
        path, _ = QFileDialog.getOpenFileName(self, "Import Code", "", "Text Files (*.txt);;All Files (*)")
        if path:
            with open(path, "r") as f:
                self.editor.setText(f.read())

    def export_code(self):
        path, _ = QFileDialog.getSaveFileName(self, "Export Code", "code.txt", "Text Files (*.txt);;All Files (*)")
        if path:
            with open(path, "w") as f:
                f.write(self.editor.text())

    def load_output_files(self):
        def load(file_path):
            if os.path.exists(file_path):
                with open(file_path, "r") as f:
                    return f.read()
            return "(File not found)"

        self.symbolTab.setText(load("symbol_table.txt"))
        self.quadTab.setText(load("quadruples.txt"))
        self.asmTab.setText(load("output.asm"))

if __name__ == '__main__':
    app = QApplication(sys.argv)
    window = CompilerGUI()
    window.show()
    sys.exit(app.exec_())
