# Line Items API

API endpoints for managing expense line items within reports.

## Endpoints

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Add line item | POST | `/apollo/expenseReports/{reportId}/lineItems/` |
| Update line item | PUT | `/apollo/expenseReports/{reportId}/lineItems/{lineItemId}` |
| Get line item images | GET | `/apollo/expenseReports/{reportId}/lineItems/{lineItemId}/images` |

## Get Expense Categories (for Recategorization)

Before changing an expense's category, look up the available categories:

**GET** `/apollo/customer/expensetypes`

Returns all expense types configured for the customer (Databricks). Use this to get the correct `typeName` and full object structure.

**Example Response (partial):**
```json
[
  {
    "_class": "com.chromeriver.common.expense.ExpenseReportItemType",
    "typeName": "CELLPHONE",
    "displayName": "Cell Phone",
    "icon": "cell-phone",
    "formName": "CellPhone",
    "costCodeOriginal": "18"
  },
  {
    "_class": "com.chromeriver.common.expense.ExpenseReportItemType",
    "typeName": "INTERNETWIFI",
    "displayName": "Internet / WiFi (Home)",
    "icon": "internet",
    "formName": "HomeInternet",
    "costCodeOriginal": "19"
  },
  {
    "_class": "com.chromeriver.common.expense.ExpenseReportItemType",
    "typeName": "RIDESHARE",
    "displayName": "Rideshare",
    "icon": "ground",
    "formName": "Rideshare"
  }
]
```

**Common Expense Type Codes:**

| typeName | displayName | Notes |
|----------|-------------|-------|
| CELLPHONE | Cell Phone | Single line only |
| INTERNETWIFI | Internet / WiFi (Home) | $50/month limit |
| FITNESS | Fitness | $250/month limit |
| RIDESHARE | Rideshare | Uber, Lyft, etc. |
| TAXI | Taxi | |
| BUSINESSMEAL | Business Meal | Internal only |
| BUSINESSMEALEXT | Business Meal (External) | Requires attendees |
| HOTEL | Hotel | |
| AIRFARE | Airfare | |
| AIRWIFI | In-Flight WiFi | |
| CONFSEM | Conference/Seminar | Learning, training |

## Update Line Item (Change Category)

**PUT** `/apollo/expenseReports/{reportId}/lineItems/{lineItemId}`

To change an expense's category (recategorize), you need to update the `expenseReportItemType` on both the line item AND the nested `expenseTransaction`:

```json
{
  "_class": "com.chromeriver.common.expense.ExpenseReportLineItem",
  "id": "<lineItemId>",
  "expenseReportItemType": {
    "typeName": "CELLPHONE",
    "_class": "com.chromeriver.common.expense.ExpenseReportItemType",
    "displayName": "Cell Phone"
  },
  "expenseTransaction": {
    "expenseReportItemType": {
      "typeName": "CELLPHONE",
      "_class": "com.chromeriver.common.expense.ExpenseReportItemType",
      "displayName": "Cell Phone"
    },
    "expenseReportItemTypeName": "CELLPHONE"
  }
}
```

**Key Fields for Category Change:**
- `expenseReportItemType.typeName` - The category code (e.g., "CELLPHONE")
- `expenseTransaction.expenseReportItemType.typeName` - Must match
- `expenseTransaction.expenseReportItemTypeName` - Must match

**Example: Recategorize from INTERNETWIFI to CELLPHONE**

```javascript
// First, get the current line item to preserve other fields
const lineItem = await fetch('/apollo/expenseReports/<reportId>/lineItems/<lineItemId>', {
  headers: { /* ... standard headers ... */ }
}).then(r => r.json());

// Update the category fields
lineItem.expenseReportItemType = {
  typeName: 'CELLPHONE',
  _class: 'com.chromeriver.common.expense.ExpenseReportItemType',
  displayName: 'Cell Phone'
};
lineItem.expenseTransaction.expenseReportItemType = lineItem.expenseReportItemType;
lineItem.expenseTransaction.expenseReportItemTypeName = 'CELLPHONE';

// PUT the updated line item
await fetch('/apollo/expenseReports/<reportId>/lineItems/<lineItemId>', {
  method: 'PUT',
  headers: { /* ... standard headers ... */ },
  body: JSON.stringify(lineItem)
});
```

## Add Line Item (from eWallet Transaction)

**POST** `/apollo/expenseReports/{reportId}/lineItems/`

The request body includes the full `expenseTransaction` object from eWallet plus allocation (`matters`) and UDAs.

**Note:** The `matters` (allocation) values are user-specific. Look up the user's valid allocation codes via `/apollo/matters?searchTerm={term}&type=LINEITEM` before adding line items.

**IMPORTANT:** Include ALL fields from the transaction object - the API may fail or behave unexpectedly if fields are omitted.

```json
{
  "_class": "com.chromeriver.common.expense.ExpenseReportLineItem",
  "lineNumber2": 0,
  "expenseTransaction": {
    "expenseReportItemType": {
      "typeName": "INTERNETWIFI",
      "_class": "com.chromeriver.common.expense.ExpenseReportItemType",
      "icon": "internet",
      "displayName": "Internet / WiFi (Home)",
      "tooltip": "",
      "formName": "HomeInternet",
      "rules": [],
      "references": [],
      "costCodeOriginal": "19",
      "drawer": []
    },
    "_class": "com.chromeriver.common.expense.transaction.ExpenseTransaction",
    "id": 178905836,
    "expenseTransactionId": 178905836,
    "customerId": 3035,
    "personId": 6495204,
    "feedId": 44059,
    "feedTypeId": 3,
    "isCreditCard": false,
    "expenseReportItemTypeId": 637638,
    "expenseReportItemTypeName": "INTERNETWIFI",
    "defaultMatterID": 0,
    "enableDefaultMatter": true,
    "createDate": "2025-10-20 03:19:46:000",
    "transactionDate": "2025-08-21 00:00:00:000",
    "updateDate": "2025-10-22 19:37:04:000",
    "status": "ACTIVE",
    "type": "IMAGE",
    "displayType": "IMAGE",
    "name": "xfinity",
    "vendorName": "xfinity",
    "amountSpent": 51.54,
    "amountOriginal": 51.54,
    "currencyCodeSpent": "USD",
    "currencyCodeOriginal": "USD"
  },
  "allowDuplicate": true,
  "amountCustomer": 51.54,
  "amountPayMeV2": 51.54,
  "amountSpent": 51.54,
  "currencyCodeSpent": "USD",
  "expenseReportItemType": {
    "typeName": "INTERNETWIFI",
    "_class": "com.chromeriver.common.expense.ExpenseReportItemType",
    "displayName": "Internet / WiFi (Home)"
  },
  "matters": [
    {
      "personal": false,
      "_class": "com.chromeriver.common.matter.ExpenseReportLineItemMatter",
      "description": "Cost Center",
      "matterClient": {
        "_class": "com.chromeriver.common.matter.MatterClient",
        "clientName": "FE Direct - Emerging"
      },
      "number": "651",
      "matterId": 86444569,
      "allocationAmount": 51.54,
      "percent": 100,
      "matterUniqueId": "651_421"
    }
  ],
  "udas": [
    {
      "udaName": "EOSubsidiary",
      "udaDataType": "StringValue",
      "_class": "com.chromeriver.common.expense.ExpenseLineItemUda",
      "stringValue": "1"
    },
    {
      "udaName": "Merchant",
      "udaDataType": "StringValue",
      "_class": "com.chromeriver.common.expense.ExpenseLineItemUda",
      "stringValue": "xfinity"
    }
  ]
}
```

## Adding Attendees to Line Items

For business meals and events with external guests, you can add attendees to the line item.

### Internal Attendees (Databricks Employees)

Add internal attendees using the `lineItemInternalPersons` array:

```json
{
  "lineItemInternalPersons": [
    {
      "_class": "com.chromeriver.common.person.LineItemInternalPerson",
      "personId": 6495204,
      "firstName": "John",
      "lastName": "Smith",
      "email": "john.smith@databricks.com"
    }
  ]
}
```

### External Attendees (Customers/Partners)

Add external attendees using the `lineItemExternalPersons` array:

```json
{
  "lineItemExternalPersons": [
    {
      "_class": "com.chromeriver.common.person.LineItemExternalPerson",
      "firstName": "Jane",
      "lastName": "Doe",
      "company": "Acme Corp",
      "title": "VP Engineering"
    }
  ],
  "hasExternalMeals": true
}
```

### Combined Example (Business Meal with Attendees)

```json
{
  "_class": "com.chromeriver.common.expense.ExpenseReportLineItem",
  "expenseReportItemType": {
    "typeName": "BUSINESSMEALEXT",
    "_class": "com.chromeriver.common.expense.ExpenseReportItemType",
    "displayName": "Business Meal (External)"
  },
  "transactionDate": "2026-01-15 00:00:00:000",
  "amountSpent": 152.00,
  "name": "Customer dinner - Acme Corp",
  "lineItemInternalPersons": [
    {
      "_class": "com.chromeriver.common.person.LineItemInternalPerson",
      "personId": 6495204,
      "firstName": "Brandon",
      "lastName": "Kvarda",
      "email": "brandon.kvarda@databricks.com"
    }
  ],
  "lineItemExternalPersons": [
    {
      "_class": "com.chromeriver.common.person.LineItemExternalPerson",
      "firstName": "Jane",
      "lastName": "Doe",
      "company": "Acme Corp",
      "title": "VP Engineering"
    },
    {
      "_class": "com.chromeriver.common.person.LineItemExternalPerson",
      "firstName": "Bob",
      "lastName": "Johnson",
      "company": "Acme Corp",
      "title": "Director of Data"
    }
  ],
  "hasExternalMeals": true,
  "hasInternalMeals": true,
  "udas": [
    {
      "udaName": "Merchant",
      "udaDataType": "StringValue",
      "_class": "com.chromeriver.common.expense.ExpenseLineItemUda",
      "stringValue": "Blue Bottle Coffee"
    },
    {
      "udaName": "BusinessPurpose",
      "udaDataType": "StringValue",
      "_class": "com.chromeriver.common.expense.ExpenseLineItemUda",
      "stringValue": "Q1 Planning Discussion"
    }
  ]
}
```

## User Defined Attributes (UDAs)

### Line Item UDAs

| UDA Name | Type | Description |
|----------|------|-------------|
| EOSubsidiary | StringValue | Subsidiary code ("1" for Databricks, Inc.) |
| Merchant | StringValue | Merchant name |
| MerchantCity | StringValue | Merchant city |
| MerchantCountry | StringValue | Merchant country |
| MCC | StringValue | Merchant Category Code |
| BusinessPurpose | StringValue | Business justification (for meals) |
