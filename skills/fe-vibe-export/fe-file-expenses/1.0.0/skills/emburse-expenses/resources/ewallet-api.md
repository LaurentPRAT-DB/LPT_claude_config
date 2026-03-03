# eWallet (Transactions) API

The eWallet contains all uploaded receipts (from email or API) that haven't been attached to expense reports yet.

## Endpoints

| Operation | Method | Endpoint |
|-----------|--------|----------|
| List transactions | GET | `/apollo/v2/expenseTransactions?status={status}&personId={id}&...` |
| Get transaction details | GET | `/apollo/expenseTransactions/{txnId}` |
| Get transaction images | GET | `/apollo/expenseTransactions/{txnId}/images` |
| Upload receipt image | POST | `/apollo/expenseTransactions/image` |
| Delete transaction | DELETE | `/apollo/expenseTransactions/{txnId}` |

## List eWallet Transactions

**GET** `/apollo/v2/expenseTransactions`

**Query Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `status` | string | Filter by status: `ACTIVE` (unused), `EXPENSED` (attached to report), `ALL` |
| `personId` | integer | Filter by user (required) |
| `customerId` | integer | Customer ID (3035 for Databricks) |
| `startDate` | string | Filter transactions on or after this date (format: `YYYY-MM-DD`) |
| `endDate` | string | Filter transactions on or before this date |
| `feedTypeId` | integer | Filter by source: `3` = uploaded receipts, `1` = corporate card |
| `limit` | integer | Max results to return |
| `offset` | integer | Pagination offset |

**Example - List all unused receipts:**
```bash
curl -X GET 'https://app.ca1.chromeriver.com/apollo/v2/expenseTransactions?status=ACTIVE&personId=<personId>&customerId=3035' \
  -H 'customer-id: 3035' \
  -H 'person-id: <personId>' \
  -H 'logged-in-user-id: <personId>' \
  -H 'delegate-person-id: <personId>' \
  -H 'chain-id: <uuid>' \
  -H 'x-requested-with: XMLHttpRequest' \
  -H 'accept: application/json' \
  -H 'Cookie: JSESSIONID=<session-cookie>'
```

## Response Structure

```json
{
  "expenseTransactions": [
    {
      "_class": "com.chromeriver.common.expense.transaction.ExpenseTransaction",
      "expenseTransactionId": 178905836,
      "id": 178905836,
      "personId": 6495204,
      "customerId": 3035,

      "status": "ACTIVE",
      "type": "IMAGE",
      "displayType": "IMAGE",
      "feedTypeId": 3,
      "transactionSource": "Receipt",

      "createDate": "2025-10-20 03:19:46:000",
      "transactionDate": "2025-08-21 00:00:00:000",
      "updateDate": "2025-10-22 19:37:04:000",

      "name": "xfinity",
      "vendorName": "xfinity",
      "amountSpent": 51.54,
      "amountOriginal": 51.54,
      "currencyCodeSpent": "USD",

      "numImages": 3,
      "hasImage": true,
      "hasButlerImage": true,

      "udas": [
        {
          "udaName": "Merchant",
          "stringValue": "xfinity"
        }
      ]
    }
  ],
  "totalCount": 15
}
```

## Key Fields for Receipt Analysis

| Field | Description | Use Case |
|-------|-------------|----------|
| `status` | `ACTIVE` = unused, `EXPENSED` = attached | Find unused receipts |
| `createDate` | When receipt was uploaded to eWallet | Check upload age |
| `transactionDate` | Date on the receipt itself | Check receipt age |
| `vendorName` | Merchant name (from OCR or manual) | Duplicate detection |
| `amountSpent` | Amount on receipt | Duplicate detection |
| `numImages` | Number of images attached | Verify receipt has images |
| `feedTypeId` | Source: 3=receipt upload, 1=corp card | Filter by source |

## Common Analysis Patterns

### Finding Unused Receipts

```javascript
const response = await fetch('/apollo/v2/expenseTransactions?status=ACTIVE&personId=<id>', {
  headers: { 'customer-id': '3035', 'person-id': '<id>', ... }
});
const data = await response.json();
const unusedReceipts = data.expenseTransactions;
```

### Detecting Potential Duplicates

```javascript
function findPotentialDuplicates(receipts) {
  const seen = new Map();
  const duplicates = [];

  for (const receipt of receipts) {
    const key = `${receipt.vendorName?.toLowerCase()}_${receipt.amountSpent}_${receipt.transactionDate?.split(' ')[0]}`;
    if (seen.has(key)) {
      duplicates.push({ original: seen.get(key), duplicate: receipt });
    } else {
      seen.set(key, receipt);
    }
  }
  return duplicates;
}
```

## Receipt Status Lifecycle

```
Upload Receipt (email/API)
        |
   status: ACTIVE
   (visible in eWallet > Offline)
        |
Add to Expense Report Line Item
        |
   status: EXPENSED
   (no longer in eWallet list)
        |
Submit Report
        |
   (linked to submitted report)
```
