# Receipt Upload

ChromeRiver supports multiple methods for uploading receipts. This document covers the recommended programmatic approach.

## IMPORTANT: Receipt Gallery UI via Chrome DevTools MCP is the PRIMARY Method

**For Claude Code automation, use the Receipt Gallery UI with Chrome DevTools MCP.** This method:
- Handles authentication properly via the browser session
- Processes receipts through Emburse's OCR pipeline
- Places receipts in the correct eWallet location

| Method | Requires Manual Steps | Works Programmatically | Reliability | Recommended |
|--------|----------------------|------------------------|-------------|-------------|
| Receipt Gallery UI | Login only | ✅ Yes (via MCP) | ✅ High | ✅ **PRIMARY** |
| Email | No | ⚠️ Unreliable | ⚠️ Inconsistent | ⚠️ Backup only |
| Direct API | Cookie extraction | ❌ No | N/A | ❌ Not supported |

## Method 1: Receipt Gallery UI Upload (PRIMARY - Use This)

Upload receipts by automating the Receipt Gallery UI via Chrome DevTools MCP.

### Prerequisites

1. Chrome browser open with Emburse logged in at `https://app.ca1.chromeriver.com`
2. Chrome DevTools MCP server running and connected

### Python Helper Script (Recommended)

Use the `receipt_uploader.py` script for batch uploads:

```bash
# List receipt files in a directory
python3 receipt_uploader.py list ~/Downloads

# Upload all PDFs in Downloads
python3 receipt_uploader.py upload ~/Downloads/*.pdf

# Upload specific files
python3 receipt_uploader.py upload receipt1.pdf receipt2.jpg

# Batch upload ALL receipts in a directory
python3 receipt_uploader.py batch ~/Downloads

# Dry run to see what would be uploaded
python3 receipt_uploader.py upload --dry-run ~/Downloads/*.pdf
```

**Supported file types:** PDF, JPG, PNG, TIFF, HEIC, OFD
**File size limits:** 50 KB - 10 MB per file

### Manual MCP Commands (Alternative)

If you need more control, use Chrome DevTools MCP directly:

```bash
# 1. Navigate to eWallet
mcp-cli call chrome-devtools/navigate_page '{"url": "https://app.ca1.chromeriver.com/index#ewallet"}'

# 2. Take snapshot to find Receipt Gallery button
mcp-cli call chrome-devtools/take_snapshot '{}'
# Find the UID for "Receipt Gallery" button

# 3. Click Receipt Gallery
mcp-cli call chrome-devtools/click '{"uid": "<gallery_uid>"}'

# 4. Take snapshot to find Upload button
mcp-cli call chrome-devtools/take_snapshot '{}'
# Find the UID for "Upload" button

# 5. Upload file
mcp-cli call chrome-devtools/upload_file '{"uid": "<upload_uid>", "filePath": "/path/to/receipt.pdf"}'
```

**Where Receipts Appear:**
Uploaded receipts appear in **eWallet > Receipt Gallery** and are processed by Emburse's OCR to extract date, amount, and vendor.

## Method 2: Email-Based Upload (Backup Only)

**⚠️ WARNING: Email uploads have been inconsistent - receipts may not appear in eWallet reliably.**

If browser-based upload is not available, you can try email:

**Email Address:**
```
receipt@ca1.chromeriver.com
```

**Format:**
```
To: receipt@ca1.chromeriver.com
Subject: [amount] [currency]  (e.g., "45.00 USD")
Body: #note [business purpose description]
Attachments: [receipt image/PDF]
```

**Requirements:**
- Supported file types: JPG, PNG, PDF, OFD, TIFF
- File size: 50 KB - 10 MB per file
- "From" email must be registered in Emburse account

**Known Issues:**
- Emails may take 5-10 minutes to process
- Some emails never appear in eWallet
- No error notification if processing fails

## Method 3: Direct API Upload (NOT SUPPORTED)

**⚠️ WARNING: Direct API upload is NOT supported for automation.**

The API endpoint `/apollo/expenseTransactions/image` returns 405 Method Not Allowed when called externally. Additionally, the `JSESSIONID` cookie is marked `httpOnly`, making it inaccessible outside the browser context.

Use the Receipt Gallery UI approach (Method 1) instead.

## Receipt to Line Item Flow

### After Upload

Receipts uploaded via Receipt Gallery appear in eWallet and are processed through Emburse's OCR pipeline. To use them:

```
1. Upload Receipt          ->  Appears in Receipt Gallery
   (via UI/MCP)                (OCR extracts date, vendor, amount)
                                   |
2. Create Line Item        ->  From Tiles view, select expense type
                               and drag receipt from eWallet
                                   |
3. Complete Details        ->  Fill in remaining fields
                               (attendees, purpose, etc.)
```

### Adding Receipts from eWallet to Expense Report

Receipts in eWallet can be:
1. Dragged directly onto expense line items
2. Selected and added via the "Add" button when creating a new line item
3. Merged with credit card transactions in the Offline section

## Best Practices

1. **Use Receipt Gallery UI upload** - Most reliable method via Chrome DevTools MCP
2. **Batch upload multiple receipts** - Use the Python helper script
3. **Keep Chrome logged in** - The browser session must be authenticated
4. **Use appropriate file sizes** - Too small (<50KB) may fail OCR, too large (>10MB) rejected
5. **Check Receipt Gallery after upload** - Verify receipts appeared and were processed correctly
