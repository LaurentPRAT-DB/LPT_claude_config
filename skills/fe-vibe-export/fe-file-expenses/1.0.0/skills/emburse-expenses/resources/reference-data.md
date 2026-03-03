# Reference Data API

Endpoints for looking up user-specific and system reference data.

## User & Session

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get current user | GET | `/apollo/persons/activeUser` |
| Get delegates | GET | `/apollo/persons/{personId}/delegates` |

## Reference Data Endpoints

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get expense categories | GET | `/apollo/customer/expensetypes` |
| Get currencies | GET | `/apollo/currencies/` |
| Get payment accounts | GET | `/apollo/payment-accounts` |
| Get feeds | GET | `/apollo/feeds` |
| Search allocations | POST | `/apollo/matters?searchTerm={term}&type=LINEITEM` |
| Get report types | GET | `/apollo/system/entities/code/ReportType` |
| Get subsidiaries | GET | `/apollo/system/entities/code/SUB` |

## User-Specific Reference Data

**IMPORTANT:** Many values in ChromeRiver are user-specific and should NOT be hardcoded:

| Data Type | Varies By | How to Look Up |
|-----------|-----------|----------------|
| Allocation codes (matters) | Cost center, team, region | Search via `/apollo/matters?searchTerm={term}&type=LINEITEM` |
| Subsidiaries | Country, legal entity | GET `/apollo/system/entities/code/SUB` |
| Report types | Region (US, INTL, etc.) | GET `/apollo/system/entities/code/ReportType` |
| Currency | User's payment preference | GET `/apollo/currencies/` or check user profile |
| Person ID | Each user has unique ID | GET `/apollo/persons/activeUser` |

### Looking Up User's Allocation Code

```bash
POST /apollo/matters?searchTerm=emerging&type=LINEITEM
# Or by cost center number
POST /apollo/matters?searchTerm=651&type=LINEITEM
```

Response:
```json
[
  {
    "_class": "com.chromeriver.common.matter.Matter",
    "matterId": 86444569,
    "matterClient": {
      "_class": "com.chromeriver.common.matter.MatterClient",
      "clientName": "FE Direct - Emerging"
    },
    "customerId": 3035,
    "matterUniqueId": "651_421",
    "number": "651",
    "description": "Cost Center",
    "isBillable": false,
    "currencyCode": "USD"
  }
]
```

### Looking Up User's Subsidiary

```bash
GET /apollo/system/entities/code/SUB
```

Common subsidiaries for Databricks:
- Code "1" = Databricks, Inc. (US)
- Other codes exist for international subsidiaries

### Looking Up Report Types

```bash
GET /apollo/system/entities/code/ReportType
```

Use the appropriate type based on expense location:
- "US" = Travel Expenses (US)
- "INTL" = International expenses

## Expense Type Codes (Common)

| Code | Display Name | Icon | Monthly Limit |
|------|--------------|------|---------------|
| AIRFARE | Airfare | airfare | - |
| AIRWIFI | In-Flight WiFi | internet | - |
| BAGGAGE | Baggage Fees | baggage | - |
| BUSINESSMEAL | Business Meal | meals-other | - |
| BUSINESSMEALEXT | Business Meal (External) | meals-other | - |
| CARRENT | Car Rental | ground | - |
| CELLPHONE | Cell Phone | cell-phone | Single line only |
| CONFSEM | Conference/Seminar | seminar | - |
| DINNER | Dinner | meals-other | - |
| FITNESS | Fitness | default | $250 |
| GROUNDTRANS | Ground Transportation | ground | - |
| HOTEL | Hotel | lodging | - |
| INTERNETWIFI | Internet / WiFi (Home) | internet | $50 |
| LUNCH | Lunch | meals-other | - |
| MILEAGE | Mileage | mileage | - |
| PARKING | Parking | parking | - |
| RIDESHARE | Rideshare | ground | - |
| TAXI | Taxi | ground | - |

## Report Header UDAs

| UDA Name | Type | Description |
|----------|------|-------------|
| ReportType | EntityValue | Report type (US, INTL, etc.) |
| ExpenseOwnerSubsidiary | EntityValue | Subsidiary (Databricks, Inc.) |
