#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import pandas as pd
import openpyxl
from openpyxl.styles import Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from collections import Counter
import re
import tkinter as tk
from tkinter import filedialog, messagebox
import logging
import os

# Set up logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

def parse_cell(cell, listref_counter: Counter | None = None):
    """Parse a chart cell.

    Output ordering rule (requested): gloss information (paired or grouped) must appear BEFORE any listRef code tokens.

    Strategy:
    1. Collect words and glosses first.
    2. Collect literal (non-parenthesis) tokens encountered in <main>.
    3. Collect listRef codes separately (do not interleave yet).
    4. Build a combined string: WORD/GLOSS content + literals + listRef tokens at the end.

    Mismatched counts (len(glosses) != len(words)) => emit words joined, then a single parenthetical group with all glosses.
    Matched counts => emit each word with its gloss: word (gloss).
    """
    main = cell.find('main')
    if main is None:
        return ''

    # Row number (special first column)
    rownum = main.find('rownum')
    if rownum is not None:
        return rownum.text or ''

    # Move marker
    move_mkr = main.find('moveMkr')
    if move_mkr is not None:
        return move_mkr.text or ''

    # Note (for Notes column)
    note = main.find('note')
    if note is not None:
        return note.text or ''

    # Gather content
    words: list[str] = []
    literal_tokens: list[str] = []
    listref_tokens: list[str] = []

    glosses_elem = cell.find('glosses')
    gloss_texts = [g.text for g in glosses_elem.findall('gloss')] if glosses_elem is not None else []

    for elem in list(main):
        tag = elem.tag
        text = (elem.text or '').strip() if elem.text else ''
        if tag == 'word' and text:
            words.append(text)
        elif tag == 'lit':
            if text in ('(', ')'):
                # Ignore structural parentheses around listRef
                continue
            if text:
                literal_tokens.append(text)
        elif tag == 'listRef':
            code = text
            if listref_counter is not None and code:
                listref_counter[code] += 1
            if code:
                listref_tokens.append(f'({code})')
        # Other tags ignored here (handled earlier if needed)

    content_segments: list[str] = []

    if words and gloss_texts:
        if len(gloss_texts) == len(words):
            # Pair 1:1
            paired = []
            for w, g in zip(words, gloss_texts):
                if w and g:
                    paired.append(f"{w} ({g})")
                elif w:
                    paired.append(w)
            if paired:
                content_segments.append(' '.join(paired))
        else:
            # Mismatch: show words then grouped glosses
            content_segments.append(' '.join(words))
            content_segments.append(f"({ ' '.join(g for g in gloss_texts if g) })")
    elif words:
        content_segments.append(' '.join(words))
    elif gloss_texts:
        # No words but have glosses—rare; still show them
        content_segments.append(f"({ ' '.join(g for g in gloss_texts if g) })")

    # Add any literal tokens (they conceptually belong with lexical material before codes)
    if literal_tokens:
        content_segments.extend(literal_tokens)

    # Finally append listRef tokens (ensures gloss info appears first)
    if listref_tokens:
        content_segments.extend(listref_tokens)

    if not content_segments:
        # Fallback: single literal child if present
        lit = main.find('lit')
        if lit is not None and lit.text:
            return lit.text
        return ''

    joined = ' '.join(seg for seg in content_segments if seg)
    joined = re.sub(r'\s+\)', ')', joined)
    joined = re.sub(r'\(\s+', '(', joined)
    return joined

## Removed get_user_choice: script now always uses a single generic analysis column.

def convert_to_excel(input_file, output_file):
    analysis_choice = "Other/Custom"  # Forced default
    logging.debug("Starting conversion with input: %s, output: %s (forced analysis choice: %s)", input_file, output_file, analysis_choice)
    
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

    # Always use the simplified generic analysis placeholder
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

    # Collect listRef codes across the chart for legend + include in parsing
    listref_counter = Counter()

    # Extract data rows
    data = []
    for row in chart.findall('row[@type="normal"]'):
        row_data = ['']  # Blank column aligns with first empty header slot
        row_cells = row.findall('cell')
        if not row_cells:
            continue
        # Treat the last cell as Notes (consistent with earlier logic)
        body_cells = row_cells[:-1]
        notes_cell = row_cells[-1]
        for cell in body_cells:
            span = int(cell.get('cols', 1))
            value = parse_cell(cell, listref_counter)
            # Put value in first column of span, blanks in remaining to preserve alignment
            row_data.append(value)
            if span > 1:
                row_data.extend([''] * (span - 1))
        # Analysis placeholder columns
        row_data.extend([''] * len(analysis_columns))
        # Notes
        row_data.append(parse_cell(notes_cell, listref_counter))
        # Trim or pad if off due to unexpected spans
        if len(row_data) > len(sub_headers):
            logging.warning("Row %s produced %d columns; trimming to %d", row.get('id'), len(row_data), len(sub_headers))
            row_data = row_data[:len(sub_headers)]
        elif len(row_data) < len(sub_headers):
            logging.warning("Row %s produced %d columns; padding to %d", row.get('id'), len(row_data), len(sub_headers))
            row_data.extend([''] * (len(sub_headers) - len(row_data)))
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

    # (Removed conditional data validation; not relevant for single generic analysis column.)

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

    # Add Legend sheet for listRef codes (if any captured)
    try:
        if 'Legend' in wb.sheetnames:
            legend_ws = wb['Legend']
            # Clear existing (simple approach)
            for row in legend_ws['A1:Z999']:
                for cell in row:
                    cell.value = None
        else:
            legend_ws = wb.create_sheet(title='Legend')
        legend_ws['A1'] = 'Code'
        legend_ws['B1'] = 'Count'
        legend_ws['A1'].font = Font(bold=True)
        legend_ws['B1'].font = Font(bold=True)
        for idx, (code, count) in enumerate(sorted(listref_counter.items()), start=2):
            legend_ws.cell(row=idx, column=1, value=code)
            legend_ws.cell(row=idx, column=2, value=count)
        legend_ws.column_dimensions['A'].width = 12
        legend_ws.column_dimensions['B'].width = 8
    except Exception as e:
        logging.warning("Failed to add Legend sheet: %s", e)

    # Save the formatted workbook
    wb.save(output_file)
    logging.debug("Excel file saved: %s", output_file)

def main():
    # Initialize Tkinter
    root = tk.Tk()
    root.withdraw()  # Hide the main Tkinter window

    try:
        # No analysis choice prompt (simplified UX)

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

        # Open file dialog for output file with overwrite confirmation
        while True:
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
            if os.path.exists(output_file):
                logging.debug("Selected output file exists: %s", output_file)
                overwrite = messagebox.askyesno(
                    "Confirm Overwrite",
                    f"The file:\n{output_file}\nalready exists. Overwrite?"
                )
                if overwrite:
                    break
                else:
                    logging.debug("User declined overwrite; re-prompting for filename")
                    continue  # Loop back for a new filename
            else:
                break  # File does not exist; safe to proceed

        # Convert the file
        logging.debug("Starting conversion")
        convert_to_excel(input_file, output_file)
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