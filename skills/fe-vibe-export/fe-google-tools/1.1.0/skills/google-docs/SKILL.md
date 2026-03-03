---
name: google-docs
description: Open, read, create, edit, and manage Google Docs from docs.google.com URLs. Use this skill for ANY Google Docs operation - reading existing documents, creating new ones, updating content, or managing Drive files. Handles Slides and Drive files too. Use this instead of fetch for reading google docs.
---

# Google Docs Skill

Comprehensive Google Docs operations using gcloud CLI + curl (no MCP tools). This skill provides patterns and utilities for:
- **Opening/reading docs.google.com URLs** - Extract and view document content
- **Creating new documents** - With proper headings, tables, hyperlinks, images, and @mentions
- **Updating existing documents** - Modify content, add sections, format text
- **Managing Drive files** - List, search, share, and organize files

## RECOMMENDED: Use markdown_to_gdocs.py for Document Creation

**When creating documents with formatted content (bold, tables, links), use the markdown converter script:**

```bash
# Write content to a temp markdown file, then convert
cat > /tmp/doc_content.md << 'EOF'
# Document Title

## Section 1

This has **bold text** and [a link](https://example.com).

| Column 1 | Column 2 |
|----------|----------|
| **Bold** | Normal |
| Data | Data |
EOF

python3 resources/markdown_to_gdocs.py \
  --input /tmp/doc_content.md \
  --title "My Document"
```

This script properly converts:
- Headings (# through ######)
- Bold (`**text**`) and italic (`*text*`)
- Hyperlinks (`[text](url)`)
- Tables with bold cells
- Bullet and numbered lists
- Code blocks

**IMPORTANT:** Raw markdown syntax like `**bold**` will NOT render as bold if you just insert the text via the API. Use this script or apply `updateTextStyle` with `bold: true` explicitly.

## Converting Markdown Tables to Native Google Docs Tables

If you have a document with markdown pipe tables (text like `| Col1 | Col2 |`), use the table converter script to transform them into native Google Docs tables:

```bash
# Convert all markdown tables in a document
python3 resources/markdown_tables_to_gdocs.py --doc-id "YOUR_DOC_ID"

# Preview what would be converted without making changes
python3 resources/markdown_tables_to_gdocs.py --doc-id "YOUR_DOC_ID" --dry-run

# Convert without applying header styling
python3 resources/markdown_tables_to_gdocs.py --doc-id "YOUR_DOC_ID" --no-style
```

**Features:**
- Detects both standard markdown tables (with `|---|---|` separators) and simple pipe tables
- Converts to native Google Docs tables with proper cell structure
- Applies header styling by default (gray background, bold text)
- Processes tables in reverse order to preserve document indices
- Handles tables with any number of rows and columns

**Example - Before:**
```
| Persona | Pain Point | Value Proposition |
|---------|------------|-------------------|
| CFOs | Stale dashboards | Talk to data |
| CMOs | Analyst queues | Self-serve answers |
```

**Example - After:**
Native Google Docs table with gray header row and bold header text.

## Authentication

**Run `/google-auth` first** to authenticate with Google Workspace, or use the shared auth module:

```bash
# Check authentication status
python3 ../google-auth/resources/google_auth.py status

# Login if needed
python3 ../google-auth/resources/google_auth.py login

# Get access token for API calls
TOKEN=$(python3 ../google-auth/resources/google_auth.py token)
```

All Google skills share the same authentication. See `/google-auth` for details on scopes and troubleshooting.

### Quota Project

All API calls require a quota project header:

```bash
-H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Troubleshooting

1. **"API not enabled" error**: Ensure quota project is set correctly
2. **"Insufficient scopes" error**: Re-run login with all required scopes
3. **"Permission denied" error**: Check quota project access in GCP console
4. **Token expired**: Run `gdocs_auth.py login` to refresh

## Quick Start - Creating Formatted Documents from Markdown

**IMPORTANT: The helper scripts (markdown_to_gdocs.py, gdocs_builder.py) have hardcoded gcloud paths that may not work on your system. Use direct API calls instead for reliability.**

This proven 3-step workflow creates a fully formatted Google Doc from markdown content in 10-15 seconds:

```bash
TOKEN=$(gcloud auth application-default print-access-token)
QUOTA_PROJECT="gcp-sandbox-field-eng"

# Step 1: Create the document
DOC_RESPONSE=$(curl -s -X POST "https://docs.googleapis.com/v1/documents" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{"title": "My Document Title"}')

DOC_ID=$(echo "$DOC_RESPONSE" | jq -r '.documentId')
echo "Created document: $DOC_ID"

# Step 2: Insert markdown content as plain text
CONTENT=$(cat /tmp/your_markdown_file.md)
ESCAPED_CONTENT=$(echo "$CONTENT" | jq -Rs .)

curl -s -X POST "https://docs.googleapis.com/v1/documents/${DOC_ID}:batchUpdate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d "{\"requests\": [{\"insertText\": {\"location\": {\"index\": 1}, \"text\": $ESCAPED_CONTENT}}]}" > /dev/null

# Step 3: Apply formatting (see "Formatting Existing Documents" section below)
echo "Document URL: https://docs.google.com/document/d/$DOC_ID/edit"
```

**Why this approach works:**
- Direct `gcloud` commands work on any system with gcloud installed
- No dependency on helper script paths
- Fast: 10-15 seconds for complete formatted document
- Reliable: Uses official Google Docs API directly

## Formatting Existing Documents

After inserting markdown content as plain text, apply formatting in 4 steps:

### Step 1: Clean Up Markdown Markers

Use `replaceAllText` to remove markdown syntax that won't render:

```bash
curl -s -X POST "https://docs.googleapis.com/v1/documents/${DOC_ID}:batchUpdate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{
    "requests": [
      {"replaceAllText": {"containsText": {"text": "**", "matchCase": true}, "replaceText": ""}},
      {"replaceAllText": {"containsText": {"text": "### ", "matchCase": true}, "replaceText": ""}},
      {"replaceAllText": {"containsText": {"text": "## ", "matchCase": true}, "replaceText": ""}},
      {"replaceAllText": {"containsText": {"text": "# ", "matchCase": true}, "replaceText": ""}}
    ]
  }' > /dev/null
```

### Step 2: Apply Heading Styles by Pattern Matching

Create a Python script to find and format headings:

```python
#!/usr/bin/env python3
import json, subprocess

DOC_ID = "YOUR_DOC_ID"
QUOTA_PROJECT = "gcp-sandbox-field-eng"

def get_token():
    result = subprocess.run(
        ["gcloud", "auth", "application-default", "print-access-token"],
        capture_output=True, text=True
    )
    return result.stdout.strip()

def get_document():
    import urllib.request
    token = get_token()
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{DOC_ID}",
        headers={"Authorization": f"Bearer {token}", "x-goog-user-project": QUOTA_PROJECT}
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def batch_update(requests):
    import urllib.request
    token = get_token()
    data = json.dumps({"requests": requests}).encode('utf-8')
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{DOC_ID}:batchUpdate",
        data=data,
        headers={"Authorization": f"Bearer {token}", "x-goog-user-project": QUOTA_PROJECT, "Content-Type": "application/json"}
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

# Define heading patterns (customize for your document)
h1_patterns = ["Executive Summary", "Expansion Opportunities", "Revenue Projection"]
h2_patterns = ["Current State", "Target State", "Technical Details"]

doc = get_document()
requests = []

for element in doc.get('body', {}).get('content', []):
    if 'paragraph' in element:
        start_idx = element['startIndex']
        end_idx = element['endIndex']
        text = ''.join(elem['textRun'].get('content', '') for elem in element['paragraph'].get('elements', []) if 'textRun' in elem).strip()

        if any(text.startswith(p) for p in h1_patterns):
            requests.append({"updateParagraphStyle": {"range": {"startIndex": start_idx, "endIndex": end_idx}, "paragraphStyle": {"namedStyleType": "HEADING_1"}, "fields": "namedStyleType"}})
        elif any(text.startswith(p) for p in h2_patterns):
            requests.append({"updateParagraphStyle": {"range": {"startIndex": start_idx, "endIndex": end_idx}, "paragraphStyle": {"namedStyleType": "HEADING_2"}, "fields": "namedStyleType"}})

# Apply in batches of 50 (IMPORTANT: not 100+, causes 400 errors)
for i in range(0, len(requests), 50):
    batch_update(requests[i:i+50])
    print(f"Applied batch {i//50 + 1}")
```

### Step 3: Apply Bold Text Formatting

Similar pattern for bolding key phrases:

```python
bold_patterns = ["NOT At-Risk", "Strong Growth", "Revenue Impact:", "Target:"]

for element in doc.get('body', {}).get('content', []):
    if 'paragraph' in element:
        for text_elem in element['paragraph'].get('elements', []):
            if 'textRun' in text_elem:
                content = text_elem['textRun'].get('content', '')
                start = text_elem['startIndex']
                for pattern in bold_patterns:
                    if pattern in content:
                        pos = content.find(pattern)
                        requests.append({"updateTextStyle": {"range": {"startIndex": start + pos, "endIndex": start + pos + len(pattern)}, "textStyle": {"bold": True}, "fields": "bold"}})

for i in range(0, len(requests), 50):
    batch_update(requests[i:i+50])
```

### Step 4: Fix Typos with Bulk Corrections

```bash
curl -s -X POST "https://docs.googleapis.com/v1/documents/${DOC_ID}:batchUpdate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{
    "requests": [
      {"replaceAllText": {"containsText": {"text": "Eecutive", "matchCase": true}, "replaceText": "Executive"}},
      {"replaceAllText": {"containsText": {"text": "recieve", "matchCase": true}, "replaceText": "receive"}}
    ]
  }' > /dev/null
```

## Common Pitfalls and Solutions

### Problem 1: Helper Scripts Fail with "gcloud: command not found"

**Error**: `FileNotFoundError: [Errno 2] No such file or directory: '/Users/username/google-cloud-sdk/bin/gcloud'`

**Solution**: Use direct gcloud commands:
```bash
TOKEN=$(gcloud auth application-default print-access-token)  # Not helper scripts
```

### Problem 2: Markdown Markers Show Up in Document

**Symptom**: Document shows `**bold**`, `## Heading` as plain text

**Solution**: Use `replaceAllText` to remove markers after insertion (shown in Step 1 above)

### Problem 3: Content Duplication in Document

**Symptom**: Sections appear twice

**Solution**: Check that batch updates aren't applied twice. Common causes:
- Running the same batch_update call multiple times
- Reading document after updates and re-applying formatting

### Problem 4: Batch Update Fails with 400 Error

**Error**: `HTTP Error 400: Bad Request`

**Solution**: Reduce batch size to 50 (not 100+):
```python
for i in range(0, len(requests), 50):  # Safe batch size
    batch_update(requests[i:i+50])
```

### Problem 5: Formatting Takes Forever

**Symptom**: Takes 2-5 minutes for large documents

**Solution**: Use pattern matching and replaceAllText (100x faster than individual replacements)

### Problem 6: Document Has Typos

**Solution**: Create a `replaceAllText` batch with common typos (shown in Step 4 above)

### Problem 7: Tables Don't Format Well

**Solution**: Keep tables as markdown-style text. Tables with `|---|---|` separators are readable and avoid complex index calculations.

## Performance Tips

**For large documents (1000+ lines):**

1. **Use replaceAllText for cleanup** - 100x faster than individual replacements
2. **Pattern matching for headings** - Match known patterns, don't analyze every paragraph
3. **Batch size of 50** - Optimal for API rate limits
4. **Apply formatting in order**: Cleanup → Headings → Bold → Typo fixes

**Expected timing:**
- Document creation: 1-2 seconds
- Content insertion: 2-3 seconds
- Formatting (cleanup + headings + bold): 5-10 seconds
- **Total: 10-15 seconds for complete formatted document**

Compare to helper scripts: 2-5 minutes (if they work at all)

## Core Concepts

### Document Indices

Google Docs uses a 1-based index system. Every character, paragraph break, and structural element has an index.

**Critical Rules:**
1. **Always read before writing** - Get the current document structure to know exact indices
2. **Insert in REVERSE order** - When making multiple insertions, start from the highest index to avoid drift
3. **Hyperlinks must be applied at insert time** - Apply updateTextStyle in the SAME batchUpdate as insertText

### Index Structure

- Document starts at index 1 (after sectionBreak at index 0)
- Each character takes 1 index
- Newlines (`\n`) take 1 index
- Tables have complex index structures (see Table Operations below)

## API Reference

### Create a Document

```bash
TOKEN=$(gcloud auth application-default print-access-token)
curl -s -X POST "https://docs.googleapis.com/v1/documents" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{"title": "My Document"}'
```

### Read a Document

```bash
curl -s "https://docs.googleapis.com/v1/documents/${DOC_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Get Document Structure (indices only)

```bash
curl -s "https://docs.googleapis.com/v1/documents/${DOC_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" | \
  jq '.body.content[] | select(.paragraph) | {startIndex, endIndex, text: .paragraph.elements[0].textRun.content}'
```

### Batch Update

```bash
curl -s -X POST "https://docs.googleapis.com/v1/documents/${DOC_ID}:batchUpdate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{"requests": [...]}'
```

## Text Operations

### Insert Text

```json
{
  "insertText": {
    "location": {"index": 1},
    "text": "Hello World\n"
  }
}
```

### Apply Heading Style

```json
{
  "updateParagraphStyle": {
    "range": {"startIndex": 1, "endIndex": 12},
    "paragraphStyle": {"namedStyleType": "HEADING_1"},
    "fields": "namedStyleType"
  }
}
```

Available styles: `NORMAL_TEXT`, `TITLE`, `SUBTITLE`, `HEADING_1` through `HEADING_6`

### Insert Text with Hyperlink (MUST be in same batchUpdate)

```json
{
  "requests": [
    {
      "insertText": {
        "location": {"index": 1},
        "text": "Click here"
      }
    },
    {
      "updateTextStyle": {
        "range": {"startIndex": 1, "endIndex": 11},
        "textStyle": {"link": {"url": "https://example.com"}},
        "fields": "link"
      }
    }
  ]
}
```

### Apply Text Formatting

```json
{
  "updateTextStyle": {
    "range": {"startIndex": 1, "endIndex": 10},
    "textStyle": {
      "bold": true,
      "italic": false,
      "underline": false,
      "strikethrough": false,
      "foregroundColor": {"color": {"rgbColor": {"red": 0.2, "green": 0.2, "blue": 0.8}}},
      "fontSize": {"magnitude": 14, "unit": "PT"},
      "weightedFontFamily": {"fontFamily": "Roboto", "weight": 400}
    },
    "fields": "bold,italic,underline,strikethrough,foregroundColor,fontSize,weightedFontFamily"
  }
}
```

### Strikethrough (for crossing items off lists)

```json
{
  "updateTextStyle": {
    "range": {"startIndex": 5, "endIndex": 20},
    "textStyle": {"strikethrough": true},
    "fields": "strikethrough"
  }
}
```

## Table Operations

### Insert a Table

```json
{
  "insertTable": {
    "rows": 3,
    "columns": 3,
    "location": {"index": 1}
  }
}
```

### Table Index Formula

For a table starting at index T with C columns:
- Cell at row R, column C has content index: `T + 3 + R*(C*2+1) + c*2`

Example for 3x3 table starting at index 104:
- Row 0: indices 107, 109, 111
- Row 1: indices 114, 116, 118
- Row 2: indices 121, 123, 125

### Fill Table Cells (insert in REVERSE order)

```json
{
  "requests": [
    {"insertText": {"location": {"index": 125}, "text": "Cell 2,2"}},
    {"insertText": {"location": {"index": 123}, "text": "Cell 2,1"}},
    {"insertText": {"location": {"index": 121}, "text": "Cell 2,0"}},
    {"insertText": {"location": {"index": 118}, "text": "Cell 1,2"}},
    {"insertText": {"location": {"index": 116}, "text": "Cell 1,1"}},
    {"insertText": {"location": {"index": 114}, "text": "Cell 1,0"}},
    {"insertText": {"location": {"index": 111}, "text": "Header 3"}},
    {"insertText": {"location": {"index": 109}, "text": "Header 2"}},
    {"insertText": {"location": {"index": 107}, "text": "Header 1"}}
  ]
}
```

### Style Table Header Row

```json
{
  "updateTableCellStyle": {
    "tableRange": {
      "tableCellLocation": {
        "tableStartLocation": {"index": 104},
        "rowIndex": 0,
        "columnIndex": 0
      },
      "rowSpan": 1,
      "columnSpan": 3
    },
    "tableCellStyle": {
      "backgroundColor": {"color": {"rgbColor": {"red": 0.9, "green": 0.9, "blue": 0.9}}}
    },
    "fields": "backgroundColor"
  }
}
```

## Bullet Lists

### Create Bullet List

```json
{
  "requests": [
    {
      "insertText": {
        "location": {"index": 1},
        "text": "Item 1\nItem 2\nItem 3\n"
      }
    },
    {
      "createParagraphBullets": {
        "range": {"startIndex": 1, "endIndex": 21},
        "bulletPreset": "BULLET_DISC_CIRCLE_SQUARE"
      }
    }
  ]
}
```

Bullet presets: `BULLET_DISC_CIRCLE_SQUARE`, `BULLET_DIAMONDX_ARROW3D_SQUARE`, `NUMBERED_DECIMAL_ALPHA_ROMAN`, `NUMBERED_DECIMAL_NESTED`, etc.

## Images

### Insert Image from URL

```json
{
  "insertInlineImage": {
    "location": {"index": 1},
    "uri": "https://example.com/image.png",
    "objectSize": {
      "width": {"magnitude": 300, "unit": "PT"},
      "height": {"magnitude": 200, "unit": "PT"}
    }
  }
}
```

## @Mentions (Person Chips / Smart Chips)

Google Docs supports true person chips (smart chips) via the `insertPerson` request:

```json
{
  "insertPerson": {
    "personProperties": {
      "email": "user@example.com"
    },
    "location": {"index": 1}
  }
}
```

This creates an interactive person chip that shows profile info on hover. You can also use the builder script:

```bash
python3 resources/gdocs_builder.py \
  add-person --doc-id "DOC_ID" --email "user@example.com"
```

## Validating and Fixing @ Mentions

After creating or editing a document, **always read it back to verify @ mentions are proper person chips**, not just plain text like "@John Smith". Plain text mentions don't notify users and aren't clickable.

### Step 1: Read Document and Identify Text-Only Mentions

```bash
TOKEN=$(gcloud auth application-default print-access-token)
QUOTA_PROJECT="gcp-sandbox-field-eng"

# Get full document content
curl -s "https://docs.googleapis.com/v1/documents/${DOC_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" | \
  jq -r '.body.content[] | select(.paragraph) | .paragraph.elements[]? | select(.textRun) | .textRun.content' | \
  grep -oE '@[A-Za-z]+ [A-Za-z]+' | sort -u
```

This extracts any text patterns like "@First Last" that are NOT proper person chips.

**How to identify text-only mentions vs proper person chips:**
- Text-only: Shows as `textRun` element with content like "@John Smith"
- Proper chip: Shows as `person` element with `personProperties.email`

```bash
# Check if document has proper person chips
curl -s "https://docs.googleapis.com/v1/documents/${DOC_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" | \
  jq '.body.content[] | select(.paragraph) | .paragraph.elements[]? | select(.person)'
```

### Step 2: Look Up Names Using Glean MCP

When you find text-only mentions like "@John Smith", use the Glean MCP to find their email addresses:

```bash
# First check the schema
mcp-cli info glean/glean_read_api_call

# Search for the person in Glean
mcp-cli call glean/glean_read_api_call '{
  "endpoint": "/search",
  "params": {
    "query": "John Smith",
    "datasource": "people"
  }
}'
```

The Glean people search returns user profiles with email addresses. Extract the email from the results.

**Alternative: Use directory/people endpoint if available:**

```bash
mcp-cli call glean/glean_read_api_call '{
  "endpoint": "/people/search",
  "params": {
    "query": "John Smith"
  }
}'
```

### Step 3: Replace Text Mentions with Person Chips

Once you have the email address, replace the text mention with a proper person chip:

```python
#!/usr/bin/env python3
"""Replace text @mentions with proper person chips."""

import json
import subprocess
import urllib.request

DOC_ID = "YOUR_DOC_ID"
QUOTA_PROJECT = "gcp-sandbox-field-eng"

# Map of text mentions to email addresses (populated from Glean lookup)
MENTION_TO_EMAIL = {
    "@John Smith": "john.smith@databricks.com",
    "@Jane Doe": "jane.doe@databricks.com",
}

def get_token():
    result = subprocess.run(
        ["gcloud", "auth", "application-default", "print-access-token"],
        capture_output=True, text=True
    )
    return result.stdout.strip()

def get_document():
    token = get_token()
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{DOC_ID}",
        headers={"Authorization": f"Bearer {token}", "x-goog-user-project": QUOTA_PROJECT}
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def batch_update(requests):
    token = get_token()
    data = json.dumps({"requests": requests}).encode('utf-8')
    req = urllib.request.Request(
        f"https://docs.googleapis.com/v1/documents/{DOC_ID}:batchUpdate",
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "x-goog-user-project": QUOTA_PROJECT,
            "Content-Type": "application/json"
        }
    )
    with urllib.request.urlopen(req) as response:
        return json.loads(response.read())

def find_and_replace_mentions():
    doc = get_document()
    requests = []

    # Find all text mentions and their positions (process in REVERSE order)
    mentions_found = []

    for element in doc.get('body', {}).get('content', []):
        if 'paragraph' in element:
            for text_elem in element['paragraph'].get('elements', []):
                if 'textRun' in text_elem:
                    content = text_elem['textRun'].get('content', '')
                    start_idx = text_elem['startIndex']

                    for mention_text, email in MENTION_TO_EMAIL.items():
                        pos = 0
                        while True:
                            pos = content.find(mention_text, pos)
                            if pos == -1:
                                break
                            mentions_found.append({
                                'start': start_idx + pos,
                                'end': start_idx + pos + len(mention_text),
                                'email': email
                            })
                            pos += 1

    # Sort by start index descending (MUST process in reverse order!)
    mentions_found.sort(key=lambda x: x['start'], reverse=True)

    for mention in mentions_found:
        # Delete the text mention
        requests.append({
            "deleteContentRange": {
                "range": {
                    "startIndex": mention['start'],
                    "endIndex": mention['end']
                }
            }
        })
        # Insert person chip at the same location
        requests.append({
            "insertPerson": {
                "personProperties": {
                    "email": mention['email']
                },
                "location": {"index": mention['start']}
            }
        })

    if requests:
        # Process in batches of 50
        for i in range(0, len(requests), 50):
            batch_update(requests[i:i+50])
            print(f"Processed batch {i//50 + 1}")
        print(f"Replaced {len(mentions_found)} text mentions with person chips")
    else:
        print("No text mentions found to replace")

if __name__ == "__main__":
    find_and_replace_mentions()
```

### Automated Validation Workflow

**Always follow this workflow after creating documents with @ mentions:**

1. **Create the document** with your content
2. **Read the document back** to inspect the structure
3. **Search for text patterns** like `@First Last` that indicate failed mentions
4. **For each text mention found:**
   - Use Glean MCP to search for the person by name
   - Extract their email address from the results
   - Replace the text with a proper `insertPerson` request
5. **Verify the fix** by reading the document again and checking for `person` elements

### Common Issues

**Problem: "@Name" shows as plain text, not a chip**
- The `insertPerson` API requires an email address, not a name
- Always look up the email first using Glean before creating the mention

**Problem: Person chip shows "Unknown user"**
- The email address doesn't exist in the organization
- Verify the email using Glean search before inserting

**Problem: Can't find person in Glean**
- Try variations: "John Smith", "Smith, John", "jsmith"
- Check if person is in a different datasource (employees vs contractors)

## Checklists

### Create Interactive Checkboxes

```json
{
  "requests": [
    {
      "insertText": {
        "location": {"index": 1},
        "text": "Task 1\nTask 2\nTask 3\n"
      }
    },
    {
      "createParagraphBullets": {
        "range": {"startIndex": 1, "endIndex": 21},
        "bulletPreset": "BULLET_CHECKBOX"
      }
    }
  ]
}
```

**Note:** The Google Docs API can CREATE checkboxes but cannot programmatically CHECK/UNCHECK them. Users must click checkboxes manually. To indicate completed items programmatically, use strikethrough styling.

### Checklist with Strikethrough for Completed Items

Use the builder script:

```bash
# Create checklist with items 0 and 1 marked as done (strikethrough)
python3 resources/gdocs_builder.py \
  add-checklist --doc-id "DOC_ID" \
  --items '["Visit the zoo", "Check feeding times", "Take photos"]' \
  --checked '[0, 1]'
```

## Comments

### Add a Comment

```bash
curl -s -X POST "https://www.googleapis.com/drive/v3/files/${DOC_ID}/comments" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "This needs review",
    "anchor": "{\"type\":\"text\",\"start\":{\"index\":10},\"end\":{\"index\":20}}"
  }'
```

## Drive Operations

### List Files

```bash
curl -s "https://www.googleapis.com/drive/v3/files?pageSize=10&fields=files(id,name,mimeType)" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Create Folder

```bash
curl -s -X POST "https://www.googleapis.com/drive/v3/files" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Folder",
    "mimeType": "application/vnd.google-apps.folder"
  }'
```

### Move File to Folder

```bash
curl -s -X PATCH "https://www.googleapis.com/drive/v3/files/${FILE_ID}?addParents=${FOLDER_ID}&removeParents=${OLD_PARENT_ID}" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng"
```

### Share Document

```bash
curl -s -X POST "https://www.googleapis.com/drive/v3/files/${DOC_ID}/permissions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "user",
    "role": "writer",
    "emailAddress": "user@example.com"
  }'
```

Roles: `reader`, `commenter`, `writer`, `owner`

## Slides Operations

### Create Presentation

```bash
curl -s -X POST "https://slides.googleapis.com/v1/presentations" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{"title": "My Presentation"}'
```

### Add a Slide

```bash
curl -s -X POST "https://slides.googleapis.com/v1/presentations/${PRESENTATION_ID}:batchUpdate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: gcp-sandbox-field-eng" \
  -H "Content-Type: application/json" \
  -d '{
    "requests": [{
      "createSlide": {
        "slideLayoutReference": {"predefinedLayout": "TITLE_AND_BODY"}
      }
    }]
  }'
```

Layouts: `BLANK`, `TITLE`, `TITLE_AND_BODY`, `TITLE_AND_TWO_COLUMNS`, `TITLE_ONLY`, `SECTION_HEADER`, etc.

### Create Shape (Text Box, Rectangle, etc.)

```json
{
  "createShape": {
    "objectId": "unique_id",
    "shapeType": "TEXT_BOX",
    "elementProperties": {
      "pageObjectId": "slide_id",
      "size": {
        "width": {"magnitude": 3000000, "unit": "EMU"},
        "height": {"magnitude": 1000000, "unit": "EMU"}
      },
      "transform": {
        "scaleX": 1,
        "scaleY": 1,
        "translateX": 500000,
        "translateY": 500000,
        "unit": "EMU"
      }
    }
  }
}
```

Shape types: `TEXT_BOX`, `RECTANGLE`, `ELLIPSE`, `ARROW_NORTH`, `ARROW_EAST`, `ARROW_SOUTH`, `ARROW_WEST`, etc.

### Insert Image

```json
{
  "createImage": {
    "objectId": "unique_id",
    "url": "https://example.com/image.jpg",
    "elementProperties": {
      "pageObjectId": "slide_id",
      "size": {
        "width": {"magnitude": 3000000, "unit": "EMU"},
        "height": {"magnitude": 2000000, "unit": "EMU"}
      },
      "transform": {
        "scaleX": 1, "scaleY": 1,
        "translateX": 500000, "translateY": 1000000,
        "unit": "EMU"
      }
    }
  }
}
```

### Create Table

```json
{
  "createTable": {
    "objectId": "table_id",
    "rows": 4,
    "columns": 3,
    "elementProperties": {
      "pageObjectId": "slide_id",
      "size": {
        "width": {"magnitude": 8000000, "unit": "EMU"},
        "height": {"magnitude": 2500000, "unit": "EMU"}
      },
      "transform": {
        "scaleX": 1, "scaleY": 1,
        "translateX": 500000, "translateY": 1500000,
        "unit": "EMU"
      }
    }
  }
}
```

### Insert Text into Table Cell

```json
{
  "insertText": {
    "objectId": "table_id",
    "cellLocation": {"rowIndex": 0, "columnIndex": 0},
    "text": "Header",
    "insertionIndex": 0
  }
}
```

### Embed Chart from Google Sheets

```json
{
  "createSheetsChart": {
    "objectId": "chart_id",
    "spreadsheetId": "SHEETS_ID",
    "chartId": 123456789,
    "linkingMode": "LINKED",
    "elementProperties": {
      "pageObjectId": "slide_id",
      "size": {
        "width": {"magnitude": 6000000, "unit": "EMU"},
        "height": {"magnitude": 4000000, "unit": "EMU"}
      },
      "transform": {
        "scaleX": 1, "scaleY": 1,
        "translateX": 1500000, "translateY": 1500000,
        "unit": "EMU"
      }
    }
  }
}
```

Linking modes:
- `LINKED` - Chart updates when Google Sheets data changes
- `NOT_LINKED_IMAGE` - Static snapshot

### Refresh Linked Chart

```json
{"refreshSheetsChart": {"objectId": "chart_id"}}
```

### Duplicate Slide

```json
{
  "duplicateObject": {
    "objectId": "slide_id_to_copy",
    "objectIds": {"slide_id_to_copy": "new_slide_id"}
  }
}
```

### Set Slide Background

```json
{
  "updatePageProperties": {
    "objectId": "slide_id",
    "pageProperties": {
      "pageBackgroundFill": {
        "solidFill": {"color": {"rgbColor": {"red": 0.1, "green": 0.3, "blue": 0.5}}}
      }
    },
    "fields": "pageBackgroundFill"
  }
}
```

### Insert Text with Styling

```json
{
  "requests": [
    {"insertText": {"objectId": "shape_id", "text": "Hello World", "insertionIndex": 0}},
    {"updateTextStyle": {
      "objectId": "shape_id",
      "textRange": {"type": "ALL"},
      "style": {"bold": true, "fontSize": {"magnitude": 24, "unit": "PT"}},
      "fields": "bold,fontSize"
    }}
  ]
}
```

### Create Bullet Points in Slides

```json
{
  "createParagraphBullets": {
    "objectId": "shape_id",
    "textRange": {"type": "ALL"},
    "bulletPreset": "BULLET_DISC_CIRCLE_SQUARE"
  }
}
```

## Helper Scripts

See `/resources/` directory for Python helper scripts:

### gslides_builder.py - Build presentations with proper element management

```bash
# Create a new presentation
python3 gslides_builder.py create --title "My Presentation"

# Get presentation info
python3 gslides_builder.py info --pres-id "PRES_ID"
python3 gslides_builder.py info --pres-id "PRES_ID" --full

# List all slides
python3 gslides_builder.py list-slides --pres-id "PRES_ID"

# Add a slide with layout
python3 gslides_builder.py add-slide --pres-id "PRES_ID" --layout "TITLE_AND_BODY"

# Duplicate a slide
python3 gslides_builder.py duplicate-slide --pres-id "PRES_ID" --page-id "SLIDE_ID"

# Delete a slide
python3 gslides_builder.py delete-slide --pres-id "PRES_ID" --page-id "SLIDE_ID"

# Set slide background
python3 gslides_builder.py set-background --pres-id "PRES_ID" --page-id "SLIDE_ID" \
  --color '{"red": 0.2, "green": 0.4, "blue": 0.6}'

# Add a text box
python3 gslides_builder.py add-text-box --pres-id "PRES_ID" --page-id "SLIDE_ID" \
  --text "Hello World" --x 1 --y 1 --width 3 --height 1 --font-size 24 --bold

# Add an image
python3 gslides_builder.py add-image --pres-id "PRES_ID" --page-id "SLIDE_ID" \
  --url "https://example.com/image.jpg" --x 1 --y 2 --width 4 --height 3

# Add a table with data
python3 gslides_builder.py add-table --pres-id "PRES_ID" --page-id "SLIDE_ID" \
  --rows 4 --cols 3 \
  --data '[["Header1","Header2","Header3"],["A","B","C"],["D","E","F"],["G","H","I"]]'

# Add a chart from Google Sheets
python3 gslides_builder.py add-chart --pres-id "PRES_ID" --page-id "SLIDE_ID" \
  --spreadsheet-id "SHEETS_ID" --chart-id 123456789 \
  --x 1 --y 1.5 --width 6 --height 4

# Copy entire presentation
python3 gslides_builder.py copy --pres-id "PRES_ID" --title "Copy of Presentation"

# Set placeholder text (TITLE, SUBTITLE, BODY)
python3 gslides_builder.py set-placeholder --pres-id "PRES_ID" --page-id "SLIDE_ID" \
  --type "TITLE" --text "My Slide Title"
```

### EMU (English Metric Units) Reference

Slides API uses EMU for positioning:
- 1 inch = 914400 EMU
- 1 point = 12700 EMU
- Standard slide: 10" x 5.625" (16:9 aspect ratio)

### gdocs_builder.py - Build complex documents with proper index management

```bash
# Create a new document
python3 gdocs_builder.py create --title "My Document"

# Read document structure (shows indices)
python3 gdocs_builder.py read --doc-id "DOC_ID"
python3 gdocs_builder.py read --doc-id "DOC_ID" --full  # Full JSON

# Get end index
python3 gdocs_builder.py end-index --doc-id "DOC_ID"

# Add a section with heading
python3 gdocs_builder.py add-section --doc-id "DOC_ID" \
  --heading "Introduction" --text "Content here." --level 1

# Add a table with hyperlinks
python3 gdocs_builder.py add-table --doc-id "DOC_ID" \
  --rows 3 --cols 3 \
  --data '[["A","B","C"],["D","E","F"],["G","H","I"]]' \
  --links '{"0,1": "https://example.com"}'

# Add a person chip (smart chip)
python3 gdocs_builder.py add-person --doc-id "DOC_ID" \
  --email "user@example.com"

# Add a checklist with completed items (strikethrough)
python3 gdocs_builder.py add-checklist --doc-id "DOC_ID" \
  --items '["Task 1", "Task 2", "Task 3"]' \
  --checked '[0]'

# Add a bulleted list
python3 gdocs_builder.py add-bullets --doc-id "DOC_ID" \
  --items '["Point 1", "Point 2", "Point 3"]' \
  --preset "BULLET_DISC_CIRCLE_SQUARE"

# Apply strikethrough to a text range
python3 gdocs_builder.py strikethrough --doc-id "DOC_ID" \
  --start 10 --end 25
```

### markdown_to_gdocs.py - Convert markdown files to Google Docs

```bash
# Create new doc from markdown
python3 markdown_to_gdocs.py --input /path/to/file.md --title "Doc Title"

# Append to existing doc
python3 markdown_to_gdocs.py --input /path/to/file.md --doc-id "DOC_ID"
```

### markdown_tables_to_gdocs.py - Convert markdown tables in existing docs

```bash
# Convert all markdown pipe tables to native Google Docs tables
python3 markdown_tables_to_gdocs.py --doc-id "DOC_ID"

# Preview tables without converting
python3 markdown_tables_to_gdocs.py --doc-id "DOC_ID" --dry-run

# Convert without header styling (no gray background/bold)
python3 markdown_tables_to_gdocs.py --doc-id "DOC_ID" --no-style
```

Features:
- Detects markdown tables with or without separator lines (`|---|---|`)
- Converts to native Google Docs tables
- Applies header styling (gray background, bold text) by default
- Handles any number of rows and columns

### gdocs_auth.py - Authentication management

```bash
python3 gdocs_auth.py status    # Check auth status
python3 gdocs_auth.py login     # Login with required scopes
python3 gdocs_auth.py token     # Get access token
python3 gdocs_auth.py validate  # Validate current token
```

## Best Practices

1. **Always read document state before modifications** - Indices change after every update
2. **Batch your updates** - Multiple requests in one batchUpdate are atomic
3. **Insert in reverse order** - Highest index first to prevent drift
4. **Apply styles at insert time** - Especially hyperlinks
5. **Use the helper scripts** - They handle index calculations correctly
6. **Limit table batches to 5 rows** - Prevents API timeouts
7. **Verify after each batch** - Read document to confirm changes

## Example: Create a Complete Document

```bash
#!/bin/bash
TOKEN=$(gcloud auth application-default print-access-token)
QUOTA_PROJECT="gcp-sandbox-field-eng"

# 1. Create document
DOC_ID=$(curl -s -X POST "https://docs.googleapis.com/v1/documents" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{"title": "Project Status Report"}' | jq -r '.documentId')

echo "Created document: $DOC_ID"

# 2. Add content with heading
curl -s -X POST "https://docs.googleapis.com/v1/documents/${DOC_ID}:batchUpdate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "x-goog-user-project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{
    "requests": [
      {"insertText": {"location": {"index": 1}, "text": "Project Status Report\n\nThis document tracks our progress.\n"}},
      {"updateParagraphStyle": {"range": {"startIndex": 1, "endIndex": 22}, "paragraphStyle": {"namedStyleType": "TITLE"}, "fields": "namedStyleType"}}
    ]
  }'

echo "Document URL: https://docs.google.com/document/d/${DOC_ID}/edit"
```
