# Expense Reports API

API endpoints for creating and managing expense reports.

## Endpoints

| Operation | Method | Endpoint |
|-----------|--------|----------|
| List draft reports | GET | `/apollo/expenseReportSummaries/?listType=DRAFT` |
| List submitted reports | GET | `/apollo/expenseReportSummaries/?listType=SUBMITTED` |
| Get report details | GET | `/apollo/expenseReports/{reportId}` |
| Get report header only | GET | `/apollo/expenseReports/{reportId}?headerOnly=true` |
| Create report | POST | `/apollo/expenseReports/` |
| Submit report | POST | `/apollo/expenseReports/{reportId}/submit` |

## Create Expense Report

**POST** `/apollo/expenseReports/`

**Note:** The `personId`, `ReportType`, and `ExpenseOwnerSubsidiary` values below are examples. Look these up dynamically using the reference data APIs.

```json
{
  "_class": "com.chromeriver.common.expense.ExpenseReportHeader",
  "personId": 6495204,
  "personIdCreator": 6495204,
  "name": "Report Name",
  "statusId": 2,
  "status": "DRAFT",
  "createDate": "2026-01-18 18:26:31:447",
  "numImages": 0,
  "hasNotes": false,
  "hasComplianceItems": false,
  "hasUdaData": true,
  "udas": [
    {
      "udaName": "ReportType",
      "udaDataType": "EntityValue",
      "_class": "com.chromeriver.common.expense.ExpenseHeaderUda",
      "entityValue": {
        "_class": "com.chromeriver.common.entity.Entity",
        "entityTypeCode": "ReportType",
        "extraData1": "1",
        "name": "Travel Expenses (US)",
        "entityID": "29972534",
        "code": "US"
      }
    },
    {
      "udaName": "ExpenseOwnerSubsidiary",
      "udaDataType": "EntityValue",
      "_class": "com.chromeriver.common.expense.ExpenseHeaderUda",
      "entityValue": {
        "_class": "com.chromeriver.common.entity.Entity",
        "entityTypeCode": "SUB",
        "extraData1": "US",
        "name": "Databricks, Inc.",
        "entityID": "30553404",
        "code": "1"
      }
    }
  ],
  "payMeInCurrencyCode": "USD",
  "payMeAmount": 0,
  "reportId": "",
  "lineItems": [],
  "hasLineItems": false,
  "hasReceiptsAttached": false,
  "complianceItems": []
}
```

**Response:** Returns the created report with `expenseReportHeaderId` and `reportId`.

## Submit Report

**POST** `/apollo/expenseReports/{reportId}/submit`

```json
{
  "_class": "com.chromeriver.common.expense.ExpenseSubmit",
  "expenseReportHeaderId": "<report-id>",
  "status": "DRAFT",
  "actionStatus": "submit",
  "complianceItems": []
}
```

**Response:** Returns compliance status. If `statusValidated` is "Validated", the report is submitted. If "Violation" or "Warning", compliance items must be addressed.

## Compliance Items

Compliance items are policy violations or warnings. Common policy IDs:

| Policy ID | Description | Action |
|-----------|-------------|--------|
| 202 | Expense over 90 days old | Provide explanation in response field |
| 322 | Monthly expense limit exceeded | May need manager approval |

To address a compliance warning, update the line item with a `response` field:

```json
{
  "complianceItems": [
    {
      "_class": "com.chromeriver.common.expense.ComplianceItem",
      "policyId": "202",
      "response": "Explanation for late submission"
    }
  ]
}
```
