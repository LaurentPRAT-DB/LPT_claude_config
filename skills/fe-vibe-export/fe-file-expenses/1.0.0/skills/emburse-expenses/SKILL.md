---
name: emburse-expenses
description: Emburse ChromeRiver API primitives for expense management - create reports, add expenses, link receipts, submit reports
---

# Emburse ChromeRiver API Skill

This skill provides the API documentation and primitives for programmatically interacting with Emburse ChromeRiver expense management system. Use this as a foundation for building expense workflows.

## Quick Reference

| Resource | Description | When to Use |
|----------|-------------|-------------|
| [Authentication](resources/authentication.md) | Okta SSO flow, session management | Initial setup, session expired |
| [Reports API](resources/reports-api.md) | Create/submit expense reports | Creating new reports |
| [Line Items API](resources/line-items-api.md) | Add/update line items, attendees | Adding expenses to reports |
| [eWallet API](resources/ewallet-api.md) | List/manage uploaded receipts | Finding existing receipts |
| [Receipt Upload](resources/receipt-upload.md) | Email and API upload methods | Uploading new receipts |
| [Reference Data](resources/reference-data.md) | Categories, allocations, user data | Looking up codes |
| [UI Automation](resources/ui-automation.md) | Chrome DevTools MCP patterns | Editing line items, changing categories |

## Base URL

```
https://app.ca1.chromeriver.com/apollo/
```

## Required Headers

All API requests must include:

```
customer-id: 3035
person-id: <user-person-id>
logged-in-user-id: <user-person-id>
delegate-person-id: <user-person-id>
chain-id: <unique-uuid-per-request>
x-requested-with: XMLHttpRequest
content-type: application/json
accept: application/json
```

## API vs UI Automation

| Operation | Recommended | Notes |
|-----------|-------------|-------|
| Create report | API | Faster, single request |
| List reports/transactions | API | Always use API for queries |
| Add line items from eWallet | **UI** | Handles complex form flows automatically |
| Change expense category | **UI** | API approach requires complex object updates |
| Modify amounts | Both | UI is simpler (Edit -> Fill -> Save) |
| Fill dropdowns | **UI** | Use `fill` tool for Angular Material selects |
| Upload receipts | API/Email | Email upload is most reliable |

**Key UI Automation Insight:** Use the `fill` tool instead of `click` for dropdown selection. Angular Material dropdowns don't respond reliably to click events on options.

See [UI Automation](resources/ui-automation.md) for detailed patterns.

## Common Workflows

### 1. File New Expenses

```
Authenticate -> Get User Info -> Check eWallet -> Create Report -> Add Line Items
```

See: [Authentication](resources/authentication.md), [Reports API](resources/reports-api.md), [Line Items API](resources/line-items-api.md)

### 2. Upload and Process Receipts

```
Upload via Email/API -> Wait for Processing -> List eWallet -> Add to Report
```

See: [Receipt Upload](resources/receipt-upload.md), [eWallet API](resources/ewallet-api.md)

### 3. Add Attendees to Meals

```
Create Line Item -> Add Internal/External Persons
```

See: [Line Items API](resources/line-items-api.md) - "Adding Attendees to Line Items" section

### 4. Edit Line Items via UI

```
Navigate to Report -> Click Line Item -> Click Edit -> Modify Fields -> Save
```

See: [UI Automation](resources/ui-automation.md) - "Editing Line Items" section

### 5. Change Expense Category via UI

```
Navigate to Report -> Click Line Item -> Click "Edit expense item type" -> Select Category -> Fill Fields -> Save
```

**Note:** This creates a NEW line item with the new category. The original remains unchanged.

See: [UI Automation](resources/ui-automation.md) - "Changing Expense Category" section

## API Endpoint Summary

### User & Session
| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get current user | GET | `/apollo/persons/activeUser` |
| Keep alive | POST | `/apollo/system/cr-internal/keepAlive` |

### Reports
| Operation | Method | Endpoint |
|-----------|--------|----------|
| List drafts | GET | `/apollo/expenseReportSummaries/?listType=DRAFT` |
| List submitted | GET | `/apollo/expenseReportSummaries/?listType=SUBMITTED` |
| Get report | GET | `/apollo/expenseReports/{reportId}` |
| Create report | POST | `/apollo/expenseReports/` |
| Submit report | POST | `/apollo/expenseReports/{reportId}/submit` |

### Line Items
| Operation | Method | Endpoint |
|-----------|--------|----------|
| Add line item | POST | `/apollo/expenseReports/{reportId}/lineItems/` |
| Update line item | PUT | `/apollo/expenseReports/{reportId}/lineItems/{lineItemId}` |

### eWallet
| Operation | Method | Endpoint |
|-----------|--------|----------|
| List transactions | GET | `/apollo/v2/expenseTransactions?status={status}` |
| Upload image | POST | `/apollo/expenseTransactions/image` |

### Reference Data
| Operation | Method | Endpoint |
|-----------|--------|----------|
| Expense categories | GET | `/apollo/customer/expensetypes` |
| Search allocations | POST | `/apollo/matters?searchTerm={term}&type=LINEITEM` |
| Report types | GET | `/apollo/system/entities/code/ReportType` |

## Expense Categories (Common)

| Code | Display Name | Limit |
|------|--------------|-------|
| INTERNETWIFI | Internet / WiFi (Home) | $50/month |
| CELLPHONE | Cell Phone | Single line only |
| FITNESS | Fitness | $250/month |
| RIDESHARE | Rideshare | - |
| BUSINESSMEAL | Business Meal | - |
| BUSINESSMEALEXT | Business Meal (External) | - |
| HOTEL | Hotel | - |
| AIRFARE | Airfare | - |
| AIRWIFI | In-Flight WiFi | - |

See [Reference Data](resources/reference-data.md) for full list.

## Emburse URLs

| Page | URL |
|------|-----|
| Okta SSO | `https://databricks.okta.com/app/databricks_chromeriver_1/exk1n5wwxjvwa24Km1d8/sso/saml?fromHome=true` |
| Draft Reports | `https://app.ca1.chromeriver.com/index#expenses/draft` |
| Submitted Reports | `https://app.ca1.chromeriver.com/index#expenses/submitted` |
| eWallet | `https://app.ca1.chromeriver.com/index#ewallet` |
| Report Details | `https://app.ca1.chromeriver.com/index#expense/draft/<reportId>/details` |

## Executing Requests

### Recommended: Chrome DevTools MCP

Execute API calls in authenticated browser context:

```javascript
// Using chrome-devtools/evaluate_script
fetch('/apollo/v2/expenseTransactions?status=ACTIVE', {
  headers: {
    'customer-id': '3035',
    'person-id': '<personId>',
    'logged-in-user-id': '<personId>',
    'delegate-person-id': '<personId>',
    'chain-id': crypto.randomUUID(),
    'x-requested-with': 'XMLHttpRequest',
    'accept': 'application/json'
  }
}).then(r => r.json()).then(console.log)
```

See [Authentication](resources/authentication.md) for alternative methods.

## Error Handling

| Situation | Action |
|-----------|--------|
| Auth required | Wait for user to complete Okta login |
| Session expired | Call keepAlive or re-authenticate |
| API error | Report error, include status code |
| Compliance violation | Address items before submission |

## Architecture

This skill is a **primitive** for building higher-level workflows:

- **file-expenses** skill - Automates full expense filing
- **historical-profile-builder** agent - Analyzes expense patterns
- **expense-identifier** agent - Finds potential expenses
- **expense-line-item-processor** agent - Processes receipts into line items
