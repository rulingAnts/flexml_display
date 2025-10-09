#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import pandas as pd
import openpyxl
from openpyxl.styles import Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import logging

# Set up logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

def parse_cell(cell):
    """Parse a cell to extract vernacular, gloss, and other content."""
    main = cell.find('main')
    if main is None:
        return ''

    # Get row number (for first column)
    rownum = main.find('rownum')
    if rownum is not None:
        return rownum.text or ''

    # Get move marker (e.g., Preposed)
    move_mkr = main.find('moveMkr')
    if move_mkr is not None:
        return move_mkr.text or ''

    # Get note (for Notes column)
    note = main.find('note')
    if note is not None and note.text:
        return note.text
    if note is not None:
        return ''  # Keep Notes column even if empty

    # Get literal (e.g., ---)
    lit = main.find('lit')
    if lit is not None:
        return lit.text or ''  # Preserve --- and other literals

    # Get vernacular words and glosses
    words = main.findall('word')
    glosses = cell.find('glosses')
    gloss_texts = [g.text for g in glosses.findall('gloss')] if glosses is not None else []

    if not words:
        return ''

    # Combine words and glosses
    vernacular = ' '.join(word.text for word in words if word.text)
    if gloss_texts and len(gloss_texts) == len(words):
        gloss = ' '.join(gloss_texts)
        return f"{vernacular} ({gloss})"
    return vernacular

def get_user_choice(root):
    """Prompt user to choose analysis type using a dropdown list."""
    logging.debug("Opening ChoiceDialog")
    class ChoiceDialog(tk.Toplevel):
        def __init__(self, parent):
            super().__init__(parent)
            logging.debug("Initializing ChoiceDialog")
            self.title("Text Chart Analysis")
            self.geometry("400x200")
            self.resizable(False, False)
            self.choice = None

            # Label
            tk.Label(self, text="What do you want to do with this Text Chart?", wraplength=350).pack(pady=10)

            # Dropdown
            choices = [
                "Analyze Clause Relationships (Including Clause Chains and Switch Reference)",
                "Analyze Serial Verb Constructions and Other Clause-Internal Structure",
                "Other/Custom"
            ]
            self.var = tk.StringVar(self)
            self.var.set(choices[0])  # Default to first choice
            dropdown = ttk.OptionMenu(self, self.var, choices[0], *choices)
            dropdown.pack(pady=10)
            logging.debug("Dropdown created with choices: %s", choices)

            # Buttons
            tk.Button(self, text="OK", command=self.on_ok).pack(pady=5)
            tk.Button(self, text="Cancel", command=self.on_cancel).pack(pady=5)

            # Log window display
            logging.debug("ChoiceDialog displayed, waiting for user input")

        def on_ok(self):
            self.choice = self.var.get()
            logging.debug("User selected: %s", self.choice)
            self.destroy()

        def on_cancel(self):
            self.choice = None
            logging.debug("User canceled")
            self.destroy()

    dialog = ChoiceDialog(root)
    root.wait_window(dialog)
    logging.debug("ChoiceDialog closed, returning choice: %s", dialog.choice)
    return dialog.choice

def convert_to_excel(input_file, output_file, analysis_choice):
    logging.debug("Starting conversion with input: %s, output: %s, choice: %s", input_file, output_file, analysis_choice)
    
    # Parse the XML file
    try:
        tree = ET.parse(input_file)
        root = tree.getroot()
        chart = root.find('chart')
    except ET.ParseError as e:
        logging.error("XML parsing failed: %s", str(e))
        raise Exception(f"Failed to parse XML file: {str(e)}")

    # Extract headers
    title1_row = chart.find('row[@type="title1"]')
    title2_row = chart.find('row[@type="title2"]')

    # Dynamically extract main headers and their spans from title1 row
    main_headers = [('', 1)]  # Blank column
    for cell in title1_row.findall('cell'):
        cols = int(cell.get('cols', 1))
        lit = cell.find('main/lit')
        header_text = lit.text if lit is not None else ''
        main_headers.append((header_text, cols))

    # Define analysis columns based on user choice
    analysis_columns = []
    if analysis_choice == "Analyze Clause Relationships (Including Clause Chains and Switch Reference)":
        analysis_columns = [
            "Dependent?",
            "Subordinate?",
            "Quotation?",
            "Same/Different Subject w/ Next",
            "Same/Different Subject w/ Main",
            "Temporal Overlap",
            "Related to: Next?/Main?",
            "SSA Relationship"
        ]
        main_headers.insert(-1, ('', len(analysis_columns)))  # Empty header for analysis columns
    elif analysis_choice == "Analyze Serial Verb Constructions and Other Clause-Internal Structure":
        analysis_columns = [
            "Multiple verbs in Clause?",
            "Argument Shared",
            "Symmetry",
            "Symmetrical Semantic Function",
            "Asymmetrical Semantic Function",
            "Tense/Aspect/Modality"
        ]
        main_headers.insert(-1, ('', len(analysis_columns)))  # Empty header for analysis columns
    else:  # Other/Custom
        analysis_columns = ["Add Analysis Columns Here"]
        main_headers.insert(-1, ('Add Analysis Columns Here', 1))

    # Extract sub-headers from title2 row, starting from cell[1] to cell[9]
    sub_headers = ['', 'Row']  # Blank column and Row
    for cell in title2_row.findall('cell')[1:-1]:  # From Outer (Topic) to Outer
        lit = cell.find('main/lit')
        sub_headers.append(lit.text if lit is not None else '')
    sub_headers.extend(analysis_columns)  # Add analysis columns
    sub_headers.append('Notes')  # Notes

    # Verify the total number of columns matches
    total_cols = sum(span for _, span in main_headers)
    if total_cols != len(sub_headers):
        logging.error("Header column mismatch: %d in title1, %d in title2", total_cols, len(sub_headers))
        raise Exception(f"Header column mismatch: {total_cols} columns in title1 (including blank and new), {len(sub_headers)} in title2")

    # Extract data rows
    data = []
    for row in chart.findall('row[@type="normal"]'):
        row_data = ['']  # Blank column
        row_cells = row.findall('cell')
        for cell in row_cells[:-1]:  # Process all cells except the last (Notes)
            if int(cell.get('cols', 1)) != 1:
                logging.error("Data row cell with cols != 1: %s", cell.get('cols'))
                raise Exception(f"Data row cell with cols != 1: {cell.get('cols')}")
            row_data.append(parse_cell(cell))
        row_data.extend([''] * len(analysis_columns))  # Add empty cells for analysis columns
        row_data.append(parse_cell(row_cells[-1]))  # Notes
        if len(row_data) != len(sub_headers):
            logging.error("Data row has %d cells, expected %d", len(row_data), len(sub_headers))
            raise Exception(f"Data row has {len(row_data)} cells, expected {len(sub_headers)}")
        data.append(row_data)

    # Create DataFrame without headers
    try:
        df = pd.DataFrame(data, columns=sub_headers)
    except ValueError as e:
        logging.error("DataFrame creation failed: %s", str(e))
        raise Exception(f"DataFrame creation failed: {str(e)}")

    # Write to Excel, starting data at row 3 (will become row 7 after inserting 4 rows)
    df.to_excel(output_file, index=False, header=False, startrow=2, engine='openpyxl')

    # Load the workbook to apply formatting
    wb = openpyxl.load_workbook(output_file)
    ws = wb.active

    # Insert four rows at the top for blank, title, subtitle, and blank
    ws.insert_rows(1, amount=4)

    # Define border styles
    thin_border = Border(
        left=Side(style='thin'),
        right=Side(style='thin')
    )
    thick_border_left = Border(left=Side(style='thick'))
    thick_border_right = Border(right=Side(style='thick'))
    thick_border_top = Border(top=Side(style='thick'))
    thick_border_bottom = Border(bottom=Side(style='thick'))

    # Add blank row (row 1)
    for col_idx in range(1, len(sub_headers) + 1):
        ws.cell(row=1, column=col_idx).value = None

    # Add title row (row 2)
    title_cell = ws.cell(row=2, column=2)  # Start at column B
    title_cell.value = "Story Title"
    title_cell.font = Font(bold=True, size=16)  # Bold, larger font for title
    title_cell.alignment = Alignment(horizontal="center", vertical="center")
    ws.merge_cells(start_row=2, start_column=2, end_row=2, end_column=len(sub_headers))  # Merge B to last

    # Add subtitle row (row 3)
    subtitle_cell = ws.cell(row=3, column=2)  # Start at column B
    subtitle_cell.value = "Text Chart"
    subtitle_cell.font = Font(bold=True, size=14)  # Bold, slightly smaller than title
    subtitle_cell.alignment = Alignment(horizontal="center", vertical="center")
    ws.merge_cells(start_row=3, start_column=2, end_row=3, end_column=len(sub_headers))  # Merge B to last

    # Add blank row (row 4)
    for col_idx in range(1, len(sub_headers) + 1):
        ws.cell(row=4, column=col_idx).value = None

    # Write main headers (row 5) and merge cells
    col_offset = 2  # Start after blank column
    for header, span in main_headers[1:]:  # Skip blank column header
        if header:
            cell = ws.cell(row=5, column=col_offset)
            cell.value = header
            cell.font = Font(bold=True, size=14)  # Bold, 2 points larger than default (12)
            cell.alignment = Alignment(horizontal="center", vertical="center")
            if span > 1:
                ws.merge_cells(start_row=5, start_column=col_offset, end_row=5, end_column=col_offset + span - 1)
        col_offset += span

    # Extend Notes header to span two rows
    notes_col = col_offset - 1
    ws.cell(row=5, column=notes_col).value = 'Notes'
    ws.cell(row=5, column=notes_col).font = Font(bold=True, size=14)
    ws.cell(row=5, column=notes_col).alignment = Alignment(horizontal="center", vertical="center")
    ws.merge_cells(start_row=5, start_column=notes_col, end_row=6, end_column=notes_col)

    # Write sub-headers (row 6), skipping Notes column
    for col_idx, header in enumerate(sub_headers[:-1], start=1):  # Exclude Notes (merged)
        cell = ws.cell(row=6, column=col_idx)
        cell.value = header
        cell.font = Font(bold=True)  # Bold, default size
        cell.alignment = Alignment(horizontal="center", vertical="center")

    # Apply column borders to data rows (starting from row 7)
    for row_idx in range(7, ws.max_row + 1):
        for col_idx in range(1, ws.max_column + 1):
            cell = ws.cell(row=row_idx, column=col_idx)
            cell.border = thin_border

    # Apply thick box border around chart (rows 5 to max_row, columns B to last)
    # Top border (row 5, columns B to last)
    for col_idx in range(2, ws.max_column + 1):
        cell = ws.cell(row=5, column=col_idx)
        cell.border = Border(
            top=Side(style='thick'),
            left=cell.border.left,
            right=cell.border.right,
            bottom=cell.border.bottom
        )

    # Bottom border (last data row, columns B to last)
    for col_idx in range(2, ws.max_column + 1):
        cell = ws.cell(row=ws.max_row, column=col_idx)
        cell.border = Border(
            bottom=Side(style='thick'),
            left=cell.border.left,
            right=cell.border.right,
            top=cell.border.top
        )

    # Left border (column B, rows 5 to max_row)
    for row_idx in range(5, ws.max_row + 1):
        cell = ws.cell(row=row_idx, column=2)
        cell.border = Border(
            left=Side(style='thick'),
            right=cell.border.right,
            top=cell.border.top,
            bottom=cell.border.bottom
        )

    # Right border (last column, rows 5 to max_row)
    for row_idx in range(5, ws.max_row + 1):
        cell = ws.cell(row=row_idx, column=ws.max_column)
        cell.border = Border(
            right=Side(style='thick'),
            left=cell.border.left,
            top=cell.border.top,
            bottom=cell.border.bottom
        )

    # Apply data validation for Choice 2
    if analysis_choice == "Analyze Serial Verb Constructions and Other Clause-Internal Structure":
        # Find column indices for "Argument Shared" and "Symmetry"
        arg_shared_col = sub_headers.index("Argument Shared") + 1  # 1-based index
        symmetry_col = sub_headers.index("Symmetry") + 1  # 1-based index

        # Data validation for "Argument Shared"
        dv1 = DataValidation(type="list", formula1='"All,Subject,Switch-Function"', allow_blank=True)
        dv1.add(f"{get_column_letter(arg_shared_col)}7:{get_column_letter(arg_shared_col)}{ws.max_row}")
        ws.add_data_validation(dv1)

        # Data validation for "Symmetry"
        dv2 = DataValidation(type="list", formula1='"Symmetrical,Asymmetrical,Both"', allow_blank=True)
        dv2.add(f"{get_column_letter(symmetry_col)}7:{get_column_letter(symmetry_col)}{ws.max_row}")
        ws.add_data_validation(dv2)

    # Adjust column widths, handling merged cells
    for col_idx in range(1, ws.max_column + 1):
        max_length = 0
        column_letter = get_column_letter(col_idx)
        for row_idx in range(1, ws.max_row + 1):
            cell = ws.cell(row=row_idx, column=col_idx)
            if isinstance(cell, openpyxl.cell.cell.MergedCell):
                continue  # Skip merged cells
            try:
                if len(str(cell.value)) > max_length:
                    max_length = len(str(cell.value))
            except:
                pass
        adjusted_width = max_length + 2
        ws.column_dimensions[column_letter].width = adjusted_width

    # Apply auto-filter using sub-header row as header, excluding column A
    ws.auto_filter.ref = f"B6:{get_column_letter(ws.max_column)}{ws.max_row}"

    # Save the formatted workbook
    wb.save(output_file)
    logging.debug("Excel file saved: %s", output_file)

def main():
    # Initialize Tkinter
    root = tk.Tk()
    root.withdraw()  # Hide the main Tkinter window

    try:
        # Prompt user for analysis choice
        logging.debug("Prompting for analysis choice")
        analysis_choice = get_user_choice(root)
        if analysis_choice is None:
            logging.info("No analysis choice selected. Exiting.")
            messagebox.showinfo("Info", "No analysis choice selected. Exiting.")
            return

        # Open file dialog for input file
        logging.debug("Opening file dialog for input")
        input_file = filedialog.askopenfilename(
            title="Select Input XML File",
            filetypes=[("XML files", "*.xml"), ("All files", "*.*")]
        )
        if not input_file:
            logging.info("No input file selected. Exiting.")
            messagebox.showinfo("Info", "No input file selected. Exiting.")
            return

        # Open file dialog for output file
        logging.debug("Opening file dialog for output")
        output_file = filedialog.asksaveasfilename(
            title="Save Output Excel File",
            defaultextension=".xlsx",
            filetypes=[("Excel files", "*.xlsx"), ("All files", "*.*")]
        )
        if not output_file:
            logging.info("No output file selected. Exiting.")
            messagebox.showinfo("Info", "No output file selected. Exiting.")
            return

        # Convert the file
        logging.debug("Starting conversion")
        convert_to_excel(input_file, output_file, analysis_choice)
        messagebox.showinfo("Success", f"Excel file '{output_file}' has been created successfully.")

    except Exception as e:
        logging.error("Error occurred: %s", str(e))
        messagebox.showerror("Error", f"An error occurred: {str(e)}")

    finally:
        # The root.destroy() should be handled by the application closing after the mainloop
        # For now, we'll keep it here, but it's part of the problem.
        # A more robust solution would manage the root window lifespan differently.
        root.destroy()
        logging.debug("Tkinter root destroyed")

if __name__ == "__main__":
    main()