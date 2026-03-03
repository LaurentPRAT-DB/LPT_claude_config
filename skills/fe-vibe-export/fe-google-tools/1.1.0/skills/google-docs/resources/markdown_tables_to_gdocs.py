#!/usr/bin/env python3
"""
Convert markdown pipe tables in a Google Doc to native Google Docs tables.

This script finds markdown-style tables (pipe-separated rows) in a Google Doc
and converts them to properly formatted native Google Docs tables with styled headers.

Usage:
    python3 markdown_tables_to_gdocs.py --doc-id "YOUR_DOC_ID"
    python3 markdown_tables_to_gdocs.py --doc-id "YOUR_DOC_ID" --dry-run
    python3 markdown_tables_to_gdocs.py --doc-id "YOUR_DOC_ID" --no-style

Features:
    - Detects both standard markdown tables (with |---|---| separators) and simple pipe tables
    - Preserves table content while converting to native format
    - Applies header styling (gray background, bold text) by default
    - Handles tables with missing header rows by detecting common patterns
    - Processes tables in reverse order to preserve document indices

Requirements:
    - gcloud CLI installed and authenticated
    - Application default credentials configured
    - Access to the target Google Doc
"""

import argparse
import json
import re
import subprocess
import sys
import urllib.request
import urllib.error

QUOTA_PROJECT = "gcp-sandbox-field-eng"


def get_token():
    """Get OAuth token from gcloud."""
    result = subprocess.run(
        ["gcloud", "auth", "application-default", "print-access-token"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Error getting token: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


def get_document(doc_id):
    """Fetch document from Google Docs API."""
    token = get_token()
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{doc_id}",
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": QUOTA_PROJECT
        }
    )
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as e:
        print(f"Error fetching document: {e.code} - {e.read().decode()}", file=sys.stderr)
        sys.exit(1)


def batch_update(doc_id, requests):
    """Send batch update to Google Docs API."""
    token = get_token()
    data = json.dumps({"requests": requests}).encode('utf-8')
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{doc_id}:batchUpdate",
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": QUOTA_PROJECT,
            "Content-Type": "application/json"
        }
    )
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError as e:
        error_msg = e.read().decode()
        print(f"Error in batch update: {e.code} - {error_msg}", file=sys.stderr)
        raise


def get_text_with_positions(doc):
    """Extract full text with character-to-index mapping."""
    full_text = ""
    char_to_index = {}

    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            for text_elem in element['paragraph'].get('elements', []):
                if 'textRun' in text_elem:
                    content = text_elem['textRun'].get('content', '')
                    start_idx = text_elem['startIndex']
                    for i, char in enumerate(content):
                        char_to_index[len(full_text) + i] = start_idx + i
                    full_text += content

    return full_text, char_to_index


def parse_markdown_table(table_text):
    """Parse markdown table text into rows and columns."""
    lines = [l.strip() for l in table_text.strip().split('\n') if l.strip()]
    rows = []

    for line in lines:
        # Skip separator lines (|---|---|)
        if re.match(r'^[-|\s]+$', line) or re.match(r'^\|[-|\s]+\|$', line):
            continue
        # Skip lines that are just pipes
        if re.match(r'^\|+$', line):
            continue
        # Parse cells
        cells = [c.strip() for c in line.split('|')]
        # Remove empty first/last from split
        cells = [c for c in cells if c]
        if cells:
            rows.append(cells)

    return rows


def find_markdown_tables(full_text):
    """Find all markdown tables in the text."""
    tables = []

    # Pattern 1: Standard markdown tables with separator lines
    pattern1 = r'\|[^\n]+\|\n\|[-|]+\|\n(\|[^\n]+\|\n)+'
    for match in re.finditer(pattern1, full_text):
        tables.append(match)

    # Pattern 2: Simple pipe tables (consecutive lines with pipes, 2+ rows)
    if not tables:
        pattern2 = r'(\|[^\n]+\|\n)+'
        for match in re.finditer(pattern2, full_text):
            lines = [l for l in match.group().strip().split('\n') if l.strip() and '|' in l]
            if len(lines) >= 2:
                tables.append(match)

    return tables


def style_table_headers(doc_id, doc):
    """Apply styling to table headers (gray background, bold text)."""
    requests = []

    for element in doc.get('body', {}).get('content', []):
        if 'table' in element:
            table = element['table']
            table_start = element['startIndex']
            num_cols = table.get('columns', 3)

            # Style header row background
            requests.append({
                "updateTableCellStyle": {
                    "tableRange": {
                        "tableCellLocation": {
                            "tableStartLocation": {"index": table_start},
                            "rowIndex": 0,
                            "columnIndex": 0
                        },
                        "rowSpan": 1,
                        "columnSpan": num_cols
                    },
                    "tableCellStyle": {
                        "backgroundColor": {
                            "color": {
                                "rgbColor": {"red": 0.9, "green": 0.9, "blue": 0.9}
                            }
                        }
                    },
                    "fields": "backgroundColor"
                }
            })

            # Bold header text
            first_row = table.get('tableRows', [{}])[0]
            for cell in first_row.get('tableCells', []):
                for content in cell.get('content', []):
                    if 'paragraph' in content:
                        for elem in content['paragraph'].get('elements', []):
                            if 'textRun' in elem:
                                start = elem['startIndex']
                                end = elem['endIndex']
                                if end > start:
                                    requests.append({
                                        "updateTextStyle": {
                                            "range": {"startIndex": start, "endIndex": end},
                                            "textStyle": {"bold": True},
                                            "fields": "bold"
                                        }
                                    })

    if requests:
        # Apply in batches
        for i in range(0, len(requests), 30):
            batch_update(doc_id, requests[i:i+30])

    return len(requests)


def convert_tables(doc_id, dry_run=False, apply_style=True):
    """Main function to convert markdown tables to Google Docs tables."""
    doc = get_document(doc_id)
    full_text, char_to_index = get_text_with_positions(doc)

    # Find markdown tables
    matches = find_markdown_tables(full_text)

    if not matches:
        print("No markdown tables found in document")
        return 0

    print(f"Found {len(matches)} markdown table(s)")

    if dry_run:
        for i, match in enumerate(matches):
            rows = parse_markdown_table(match.group())
            print(f"\nTable {i+1}: {len(rows)} rows x {max(len(r) for r in rows) if rows else 0} cols")
            if rows:
                print(f"  Header: {rows[0]}")
        return len(matches)

    # Process tables in REVERSE order to preserve indices
    for i, match in enumerate(reversed(matches)):
        table_num = len(matches) - i
        table_text = match.group()

        start_char = match.start()
        end_char = match.end()

        doc_start = char_to_index.get(start_char, start_char + 1)
        doc_end = char_to_index.get(end_char - 1, end_char) + 1

        rows = parse_markdown_table(table_text)
        if not rows or len(rows) < 1:
            continue

        num_rows = len(rows)
        num_cols = max(len(row) for row in rows)

        print(f"\nTable {table_num}: {num_rows} rows x {num_cols} cols")
        print(f"  Header: {rows[0]}")

        # Step 1: Delete markdown table text
        try:
            batch_update(doc_id, [{
                "deleteContentRange": {
                    "range": {"startIndex": doc_start, "endIndex": doc_end}
                }
            }])
            print("  Deleted markdown text")
        except Exception as e:
            print(f"  Error deleting: {e}")
            continue

        # Step 2: Insert table
        try:
            batch_update(doc_id, [{
                "insertTable": {
                    "rows": num_rows,
                    "columns": num_cols,
                    "location": {"index": doc_start}
                }
            }])
            print("  Inserted table structure")
        except Exception as e:
            print(f"  Error inserting table: {e}")
            continue

        # Step 3: Fill cells
        doc = get_document(doc_id)

        # Find the inserted table
        table_element = None
        for element in doc.get('body', {}).get('content', []):
            if 'table' in element and element['startIndex'] >= doc_start - 5:
                table_element = element
                break

        if not table_element:
            print("  Could not find inserted table")
            continue

        # Build fill requests (reverse order)
        fill_requests = []
        table_rows = table_element['table'].get('tableRows', [])

        for row_idx in range(len(table_rows) - 1, -1, -1):
            if row_idx >= len(rows):
                continue
            row_cells = table_rows[row_idx].get('tableCells', [])
            for col_idx in range(len(row_cells) - 1, -1, -1):
                if col_idx >= len(rows[row_idx]):
                    continue
                cell = row_cells[col_idx]
                cell_content = cell.get('content', [{}])[0]
                if 'paragraph' in cell_content:
                    cell_start = cell_content['paragraph']['elements'][0]['startIndex']
                    text_to_insert = rows[row_idx][col_idx]
                    if text_to_insert:
                        fill_requests.append({
                            "insertText": {
                                "location": {"index": cell_start},
                                "text": text_to_insert
                            }
                        })

        if fill_requests:
            for j in range(0, len(fill_requests), 20):
                try:
                    batch_update(doc_id, fill_requests[j:j+20])
                except Exception as e:
                    print(f"  Error filling cells: {e}")
            print(f"  Filled {len(fill_requests)} cells")

        # Refresh document for next iteration
        doc = get_document(doc_id)
        full_text, char_to_index = get_text_with_positions(doc)

    # Apply header styling
    if apply_style:
        doc = get_document(doc_id)
        style_count = style_table_headers(doc_id, doc)
        print(f"\nApplied {style_count} styling requests")

    print(f"\n✓ Converted {len(matches)} table(s)")
    print(f"\nDocument URL: https://docs.google.com/document/d/{doc_id}/edit")

    return len(matches)


def main():
    parser = argparse.ArgumentParser(
        description='Convert markdown tables in a Google Doc to native tables'
    )
    parser.add_argument(
        '--doc-id', required=True,
        help='Google Doc ID (from the URL)'
    )
    parser.add_argument(
        '--dry-run', action='store_true',
        help='Show what would be converted without making changes'
    )
    parser.add_argument(
        '--no-style', action='store_true',
        help='Skip applying header styling (gray background, bold)'
    )

    args = parser.parse_args()

    convert_tables(
        doc_id=args.doc_id,
        dry_run=args.dry_run,
        apply_style=not args.no_style
    )


if __name__ == "__main__":
    main()
