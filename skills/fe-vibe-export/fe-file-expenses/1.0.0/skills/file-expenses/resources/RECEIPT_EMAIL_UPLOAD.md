# Emburse Receipt Email Upload Guide

## Overview
Upload receipts to Emburse by emailing them to a special address. Emburse's AI-powered OCR extracts expense details automatically.

## Email Address
```
receipt@ca1.chromeriver.com
```

## Requirements

### File Types
- JPG, PNG, PDF, OFD, TIFF
- Minimum size: 50 KB
- Maximum size: 10 MB per file
- Combined size per report: 100 MB max

### From Address
The "From" email address **must** be registered in your Emburse account settings.

## Email Format

### Basic Receipt Upload
```
To: receipt@ca1.chromeriver.com
Subject: [amount] [currency]  (e.g., "45.00 USD")
Body: [optional description]
Attachments: [receipt image/PDF]
```

### With Description
```
To: receipt@ca1.chromeriver.com
Subject: 45.00 USD
Body: #note Client dinner at Blue Bottle with John Smith
Attachments: receipt.pdf
```

The `#note` prefix tells Emburse to include the first 1,500 characters in the Description field.

### Direct to Report
```
To: receipt@ca1.chromeriver.com
Subject: [Report ID]
Body: [optional]
Attachments: [receipt]
```

Use Report ID in subject to attach directly to a specific expense report.

## Upload Methods

### 1. Image Attachments
- Take photo of receipt with phone
- Attach image to email
- Each image creates a separate expense item
- OCR extracts amount, date, vendor automatically

### 2. PDF Attachments
- Attach PDF receipt/invoice
- Single-page PDFs: one expense item created
- Multi-page image-only PDFs: split into separate items (unless amount in subject)
- Multi-page PDFs with text: single item created

### 3. HTML Receipt Forwarding
- Forward HTML email receipts directly (no attachments)
- System converts HTML to PDF
- Email signature is ignored
- Works for: restaurant confirmations, airline receipts, etc.

## Subject Line Options

| Subject | Result |
|---------|--------|
| `45.00 USD` | Amount $45.00, USD currency (overrides OCR) |
| `45.00` | Amount $45.00, default currency |
| `[Report ID]` | Attaches to specific report |
| (empty) | OCR extracts amount automatically |

## Where Receipts Appear

Uploaded receipts appear in:
1. **E-Wallet > Offline** section
2. **Receipt Gallery**

From there, add them to expense reports.

## Best Practices

### For Clear OCR
- Ensure receipt image is clear and readable
- Good lighting, minimal blur
- Include full receipt (date, vendor, amount, items)

### For Faster Processing
- Put amount in subject line
- Use `#note` for business purpose
- Attach one receipt per email (or use subject amount for multi-page)

### For Organization
- Email receipts immediately after expense
- Include vendor name in description
- Add Report ID if working on a specific report

## Troubleshooting

### Receipt Not Appearing
- Check "From" email is registered in Emburse
- Verify file type is supported
- Check file size (50KB - 10MB)
- Wait a few minutes for processing

### Wrong Amount Extracted
- Re-upload with correct amount in subject line
- Or manually edit in Emburse after upload

### Receipt Rejected
- Image may be too small (<50KB) or too large (>10MB)
- File type not supported
- Try converting to PDF

## Examples

### Uber Receipt
```
To: receipt@ca1.chromeriver.com
Subject: 39.94 USD
Body: #note Client transportation - Archipelago dinner
Attachments: uber_receipt_dec3.pdf
```

### Restaurant Receipt
```
To: receipt@ca1.chromeriver.com
Subject: 52.72 USD
Body: #note Team dinner with Block engineering
Attachments: IMG_1234.jpg
```

### Hotel Folio (forward HTML)
```
To: receipt@ca1.chromeriver.com
Subject: 968.33 USD
Body: #note AWS re:Invent conference - 3 nights
(forwarded hotel confirmation email, no attachments)
```

### Monthly Bill
```
To: receipt@ca1.chromeriver.com
Subject: 80.00 USD
Body: #note Verizon - 50% business allocation
Attachments: verizon_dec_bill.pdf
```
