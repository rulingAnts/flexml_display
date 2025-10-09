#!/usr/bin/env python3
import xml.etree.ElementTree as ET
import pandas as pd
import openpyxl
from openpyxl.styles import Font, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation
from collections import Counter
import re
try:
    from openpyxl.cell.rich_text import CellRichText, TextBlock
    from openpyxl.cell.text import InlineFont
except ImportError:  # Fallback if openpyxl version lacks rich text support
    CellRichText = None
    TextBlock = None
    InlineFont = None
import tkinter as tk
from tkinter import filedialog, messagebox
import logging
import os

# Set up logging
logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

# Feature toggle: disable rich text if Excel repair warnings persist
ENABLE_RICH_TEXT = True
# Placeholder shown when a <listRef> element has no text (user hasn't configured abbreviation)
LISTREF_EMPTY_PLACEHOLDER = '?'  # Change to e.g. 'Ø' or 'UNDEF' if preferred

def parse_cell(cell, listref_counter: Counter | None = None, runs: list | None = None):
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
        text = rownum.text or ''
        if runs is not None:
            runs.append({'text': text, 'type': 'rownum'})
        return text

    # Move marker
    move_mkr = main.find('moveMkr')
    if move_mkr is not None:
        text = move_mkr.text or ''
        if runs is not None:
            runs.append({'text': text, 'type': 'move'})
        return text

    # Note (for Notes column)
    note = main.find('note')
    if note is not None:
        text = note.text or ''
        if runs is not None:
            runs.append({'text': text, 'type': 'note'})
        return text

    # Gather content
    words: list[str] = []
    literal_tokens: list[str] = []
    listref_codes: list[str] = []

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
            if not code:
                code = LISTREF_EMPTY_PLACEHOLDER
            if listref_counter is not None and code:
                listref_counter[code] += 1
            if code:
                listref_codes.append(code)
        # Other tags ignored here (handled earlier if needed)

    content_segments: list[str] = []

    if words and gloss_texts:
        if len(gloss_texts) == len(words):
            # Pair 1:1 produce runs per word and gloss separately
            word_gloss_segments = []
            for w, g in zip(words, gloss_texts):
                if w:
                    word_gloss_segments.append({'text': w, 'type': 'word'})
                if g:
                    word_gloss_segments.append({'text': ' (', 'type': 'punct'})
                    word_gloss_segments.append({'text': g, 'type': 'gloss'})
                    word_gloss_segments.append({'text': ')', 'type': 'punct'})
            if word_gloss_segments:
                content_segments.append(''.join(seg['text'] for seg in word_gloss_segments))
                if runs is not None:
                    runs.extend(word_gloss_segments)
        else:
            # Mismatch: words then grouped gloss bundle
            if words:
                content_segments.append(' '.join(words))
                if runs is not None:
                    for i, w in enumerate(words):
                        if i:
                            runs.append({'text': ' ', 'type': 'space'})
                        runs.append({'text': w, 'type': 'word'})
            gloss_bundle = [g for g in gloss_texts if g]
            if gloss_bundle:
                group_text = '(' + ' '.join(gloss_bundle) + ')'
                content_segments.append(group_text)
                if runs is not None:
                    runs.append({'text': ' ', 'type': 'space'}) if runs and runs[-1]['text'] != ' ' else None
                    runs.append({'text': '(', 'type': 'punct'})
                    for i, g in enumerate(gloss_bundle):
                        if i:
                            runs.append({'text': ' ', 'type': 'space'})
                        runs.append({'text': g, 'type': 'gloss'})
                    runs.append({'text': ')', 'type': 'punct'})
    elif words:
        content_segments.append(' '.join(words))
        if runs is not None:
            for i, w in enumerate(words):
                if i:
                    runs.append({'text': ' ', 'type': 'space'})
                runs.append({'text': w, 'type': 'word'})
    elif gloss_texts:
        # No words but have glosses—rare; group them
        grouped = '(' + ' '.join(g for g in gloss_texts if g) + ')'
        content_segments.append(grouped)
        if runs is not None:
            runs.append({'text': '(', 'type': 'punct'})
            for i, g in enumerate(g for g in gloss_texts if g):
                if i:
                    runs.append({'text': ' ', 'type': 'space'})
                runs.append({'text': g, 'type': 'gloss'})
            runs.append({'text': ')', 'type': 'punct'})

    # Add any literal tokens (they conceptually belong with lexical material before codes)
    if literal_tokens:
        content_segments.extend(literal_tokens)
        if runs is not None:
            for lit_token in literal_tokens:
                if runs and not runs[-1]['text'].endswith(' '):
                    runs.append({'text': ' ', 'type': 'space'})
                runs.append({'text': lit_token, 'type': 'literal'})

    # Finally append listRef tokens (ensures gloss info appears first)
    if listref_codes:
        if runs is not None:
            for code in listref_codes:
                # Append a space to previous run text instead of a separate space run to reduce rich text fragmentation
                if runs and not runs[-1]['text'].endswith(' '):
                    runs[-1]['text'] += ' '
                runs.append({'text': '(', 'type': 'code_punct'})
                runs.append({'text': code, 'type': 'code'})
                runs.append({'text': ')', 'type': 'code_punct'})
        content_segments.extend(f'({c})' for c in listref_codes)

    if not content_segments:
        # Fallback: single literal child if present
        lit = main.find('lit')
        if lit is not None and lit.text:
            if runs is not None:
                runs.append({'text': lit.text, 'type': 'literal'})
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
    cell_runs_matrix: list[list[list[dict] | None]] = []  # Parallel to data rows; each entry a list of runs per column or None
    break_flags: list[str | None] = []  # 'sent', 'para', or None per data row order
    for row in chart.findall('row[@type="normal"]'):
        row_data = ['']  # Blank leading column
        row_runs: list[list[dict] | None] = [None]
        row_cells = row.findall('cell')
        if not row_cells:
            continue
        body_cells = row_cells[:-1]
        notes_cell = row_cells[-1]
        for cell in body_cells:
            span = int(cell.get('cols', 1))
            runs_holder: list[dict] = []
            value = parse_cell(cell, listref_counter, runs=runs_holder)
            row_data.append(value)
            row_runs.append(runs_holder)
            if span > 1:
                for _ in range(span - 1):
                    row_data.append('')
                    row_runs.append(None)
        # Analysis placeholder columns (no runs)
        row_data.extend([''] * len(analysis_columns))
        row_runs.extend([None] * len(analysis_columns))
        # Notes
        note_runs: list[dict] = []
        note_val = parse_cell(notes_cell, listref_counter, runs=note_runs)
        row_data.append(note_val)
        row_runs.append(note_runs)
        # Normalize length
        if len(row_data) > len(sub_headers):
            logging.warning("Row %s produced %d columns; trimming to %d", row.get('id'), len(row_data), len(sub_headers))
            row_data = row_data[:len(sub_headers)]
            row_runs = row_runs[:len(sub_headers)]
        elif len(row_data) < len(sub_headers):
            pad = len(sub_headers) - len(row_data)
            logging.warning("Row %s produced %d columns; padding to %d", row.get('id'), len(row_data), len(sub_headers))
            row_data.extend([''] * pad)
            row_runs.extend([None] * pad)
        data.append(row_data)
        cell_runs_matrix.append(row_runs)
        # Determine break type for this row
        if row.get('endPara') == 'true':
            break_flags.append('para')
        elif row.get('endSent') == 'true':
            break_flags.append('sent')
        else:
            break_flags.append(None)

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

    # Apply sentence / paragraph break bottom borders inside the chart
    # Data rows start at Excel row 7; iterate over break_flags aligned to data order
    for idx, flag in enumerate(break_flags):
        if not flag:
            continue
        excel_row = 7 + idx
        # Choose border style
        if flag == 'para':
            bottom_side = Side(style='thick')
        else:  # 'sent'
            # Upgraded from thin to medium for greater visual separation
            bottom_side = Side(style='medium', color='000000')
        for col_idx in range(2, ws.max_column + 1):  # Columns B .. last (exclude leading blank col A)
            cell = ws.cell(row=excel_row, column=col_idx)
            cell.border = Border(
                left=cell.border.left,
                right=cell.border.right,
                top=cell.border.top,
                bottom=bottom_side
            )

    # (Removed conditional data validation; not relevant for single generic analysis column.)

    # Apply rich text styling to distinguish words / glosses / codes if supported
    if ENABLE_RICH_TEXT and CellRichText is not None and InlineFont is not None:
        gloss_color = 'FF1D4ED8'  # Blue
        code_color = 'FFD97706'   # Orange
        literal_color = 'FF4B5563'  # Gray

        def style_signature(run_type: str):
            if run_type == 'gloss':
                return ('gloss', gloss_color, True, False)
            if run_type in ('code', 'code_punct'):
                return ('code', code_color, False, True)
            if run_type == 'literal':
                return ('literal', literal_color, False, False)
            if run_type == 'punct':
                return ('gloss_punct', gloss_color, False, False)
            return ('default', None, False, False)

        def merge_runs(runs):
            merged = []
            for r in runs:
                txt = r['text']
                if not txt:
                    continue
                sig = style_signature(r['type'])
                if merged and style_signature(merged[-1]['type']) == sig:
                    merged[-1]['text'] += txt
                else:
                    merged.append({'text': txt, 'type': r['type']})
            return merged

        for r_index, row_runs in enumerate(cell_runs_matrix, start=7):
            for c_index, runs in enumerate(row_runs, start=1):
                if not runs:
                    continue
                cell = ws.cell(row=r_index, column=c_index)
                if cell.value in (None, ''):
                    continue
                compact = merge_runs(runs)
                # Skip overly complex cells to avoid Excel repair
                if len(compact) > 60:
                    logging.debug("Skipping rich text in %s%d (runs=%d)", get_column_letter(c_index), r_index, len(compact))
                    continue
                rich = CellRichText()
                for run in compact:
                    txt = run['text']
                    rtype = run['type']
                    _, color, italic, bold = style_signature(rtype)
                    try:
                        inline_font = InlineFont(color=color, i=italic, b=bold)
                    except Exception:
                        inline_font = InlineFont()
                    try:
                        rich.append(TextBlock(inline_font, txt))
                    except Exception as e:
                        logging.debug("Append TextBlock failed %s%d: %s", get_column_letter(c_index), r_index, e)
                try:
                    cell.data_type = 'inlineStr'
                    cell.value = rich
                except Exception as e:
                    logging.debug("Rich text assignment failed %s%d: %s", get_column_letter(c_index), r_index, e)
    else:
        logging.info("Rich text formatting not supported by this openpyxl version; skipping token-level coloring.")

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