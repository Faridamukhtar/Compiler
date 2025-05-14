import sys
import subprocess
import shutil
import os
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QPushButton,
    QTextEdit, QHBoxLayout, QFileDialog, QLabel, QTabWidget, QMessageBox
)
from PyQt5.QtGui import QFont, QColor, QTextCharFormat, QTextCursor
from PyQt5.Qsci import QsciScintilla, QsciLexerCPP

class CompilerGUI(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Compiler Frontend")
        self.resize(1000, 700)

        # Pastel theme styling with emoji-friendly fonts
        self.setStyleSheet("""
            QWidget {
                font-family: 'Noto Color Emoji', 'Segoe UI', 'Arial';
                font-size: 12pt;
                background-color: #fff0f6;
                color: #4b0082;
            }

            QLabel {
                font-weight: bold;
                color: #a64ca6;
            }

            QPushButton {
                padding: 8px 16px;
                background-color: #ffc0cb;
                color: #4b0082;
                border: 1px solid #f497b6;
                border-radius: 10px;
            }

            QPushButton:hover {
                background-color: #f497b6;
            }

            QTextEdit, QsciScintilla {
                background-color: #fffaff;
                color: #5a005a;
                border: 1px solid #d6a4cb;
                font-family: 'Courier New', 'Consolas', monospace;
                font-size: 11pt;
            }

            QTabWidget::pane {
                border: 2px solid #f497b6;
                background: #fff5fa;
            }

            QTabBar::tab {
                background: #ffe3ec;
                color: #8b008b;
                padding: 6px 12px;
                border-top-left-radius: 12px;
                border-top-right-radius: 12px;
                min-width: 130px;  
            }

            QTabBar::tab:selected {
                background: #ffc1d3;
                font-weight: bold;
                color: #5a005a;
                min-width: 130px;  
            }
        """)

        layout = QVBoxLayout()

        # Code Editor
        self.editor = QsciScintilla()
        self.editor.setUtf8(True)
        lexer = QsciLexerCPP()
        lexer.setDefaultFont(QFont("Courier New", 11))
        self.editor.setLexer(lexer)
        self.editor.setFont(QFont("Courier New", 11))
        self.editor.setMarginLineNumbers(1, True)
        self.editor.setMarginsForegroundColor(QColor("gray"))
        self.editor.setMarginWidth(1, "0000")
        self.editor.setCaretLineVisible(True)
        self.editor.setCaretLineBackgroundColor(QColor("#fce4ec"))
        self.editor.setMarginsBackgroundColor(QColor("#f8d7e8"))
        self.editor.setBraceMatching(QsciScintilla.SloppyBraceMatch)

        layout.addWidget(QLabel("Input Code:"))
        layout.addWidget(self.editor)

        # Buttons
        buttonLayout = QHBoxLayout()
        self.compileButton = QPushButton("Compile")
        self.resetButton = QPushButton("Reset")
        self.importButton = QPushButton("Import")
        self.exportButton = QPushButton("Export")

        for btn in [self.compileButton, self.resetButton, self.importButton, self.exportButton]:
            buttonLayout.addWidget(btn)
        layout.addLayout(buttonLayout)

        # Output Tabs
        self.tabs = QTabWidget()
        self.symbolTab = QTextEdit()
        self.quadTab = QTextEdit()
        self.asmTab = QTextEdit()
        for tab in [self.symbolTab, self.quadTab, self.asmTab]:
            tab.setFont(QFont("Courier New", 11))
            tab.setReadOnly(True)

        self.errorTabs = QTabWidget()
        self.errorTabs.setStyleSheet("""
            QTabBar::tab {
                min-width: 180px;
            }
        """)
        self.syntaxErrorText = QTextEdit()
        self.semanticErrorText = QTextEdit()
        self.semanticErrorText.setMinimumWidth(800)  
        for t in [self.syntaxErrorText, self.semanticErrorText]:
            t.setFont(QFont("Courier New", 11))
            t.setReadOnly(True)

        self.warningTab = QTextEdit()
        self.warningTab.setFont(QFont("Courier New", 11))
        self.warningTab.setReadOnly(True)
        self.tabs.addTab(self.warningTab, "Warnings")
        self.errorTabs.addTab(self.syntaxErrorText, "Syntax Errors")
        self.errorTabs.addTab(self.semanticErrorText, "Semantic Errors")
        self.tabs.addTab(self.errorTabs, "Errors")
        self.tabs.addTab(self.symbolTab, "Symbol Table")
        self.tabs.addTab(self.quadTab, "Quadruples")
        self.tabs.addTab(self.asmTab, "Assembly")

        layout.addWidget(self.tabs)
        self.setLayout(layout)

        # Button connections
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

        self.syntaxErrorText.clear()
        self.semanticErrorText.clear()
        self.warningTab.clear()

        syntax_lines = []
        semantic_lines = []
        warning_lines = []

        if result.stdout:
            for line in result.stdout.splitlines():
                # if "Semantic Error" in line or "Semantic Warning" in line:
                #     semantic_lines.append(line)
                if "Syntax Error" in line:
                    syntax_lines.append(line)
                elif "Semantic Warning" in line:
                    warning_lines.append(line)

        if result.stderr:
            # semantic_lines.append("--- STDERR ---")
            semantic_lines.extend(result.stderr.splitlines())

        self.highlight_errors(self.syntaxErrorText, syntax_lines)
        self.highlight_errors(self.semanticErrorText, semantic_lines)
        self.highlight_errors(self.warningTab, warning_lines, warning=True)
        self.load_output_files()

    def highlight_errors(self, text_widget, lines, warning=False):
        text_widget.clear()
        for line in lines:
            cursor = text_widget.textCursor()
            fmt = QTextCharFormat()
            if "Warning" in line or warning:
                fmt.setForeground(QColor("#ff69b4"))  # hot pink
            else:
                fmt.setForeground(QColor("#d0006f"))  # rose red
            cursor.insertText(line + "\n", fmt)

    def reset_editor(self):
        self.editor.setText("")
        for tab in [self.symbolTab, self.quadTab, self.syntaxErrorText, self.semanticErrorText, self.warningTab, self.asmTab]:
            tab.clear()

    def import_code(self):
        path, _ = QFileDialog.getOpenFileName(self, "Import Code", "", "Text Files (*.txt);;All Files (*)")
        if path:
            with open(path, "r") as f:
                self.editor.setText(f.read())

    def export_code(self):
        dir_path = QFileDialog.getExistingDirectory(self, "Select Output Folder")
        if not dir_path:
            return

        output_dir = os.path.join(dir_path, "outputs")
        os.makedirs(output_dir, exist_ok=True)

        with open(os.path.join(output_dir, "input_code.txt"), "w") as f:
            f.write(self.editor.text())

        file_map = {
            "symbol_table.txt": "symbol_table.txt",
            "quadruples.txt": "quadruples.txt",
            "output.asm": "output.asm"
        }
        for src, dst in file_map.items():
            if os.path.exists(src):
                shutil.copy(src, os.path.join(output_dir, dst))

        with open(os.path.join(output_dir, "semantic_errors.txt"), "w") as f:
            f.write(self.semanticErrorText.toPlainText())
        with open(os.path.join(output_dir, "syntax_errors.txt"), "w") as f:
            f.write(self.syntaxErrorText.toPlainText())
        with open(os.path.join(output_dir, "warnings.txt"), "w") as f:
            f.write(self.warningTab.toPlainText())

        QMessageBox.information(self, "Export Successful",
            f"Files exported to:\n{output_dir}\n")

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
