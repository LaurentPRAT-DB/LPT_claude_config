# FP_Approval__c Salesforce Object Reference

## Overview
Custom Salesforce object for managing Feature Preview Approvals. Tracks approval workflows, activities, and enrollments for feature preview programs.

## Object API Name
`FP_Approval__c`

## Key Fields for CRUD Operations

### Standard Fields
| Field API Name | Label | Type | Required | Notes |
|---|---|---|---|---|
| `Id` | Record ID | id | Auto | Read-only, auto-generated |
| `Name` | Feature Preview Approval Name | string(80) | Auto | Auto-number, read-only |
| `OwnerId` | Owner ID | reference | Yes | User or Group ID |
| `CurrencyIsoCode` | Currency ISO Code | picklist | No | Default: USD (restricted picklist) |
| `CreatedDate` | Created Date | datetime | Auto | Read-only |
| `LastModifiedDate` | Last Modified Date | datetime | Auto | Read-only |

### Important Custom Fields
| Field API Name | Label | Type | Required | Notes |
|---|---|---|---|---|
| `FP_Account__c` | Account | reference | No | Links to Account object |
| `FP_Opportunity__c` | Opportunity | reference | No | Links to Opportunity object |
| `FP_Preview_Name__c` | Preview Name | reference | No | Links to FP_Preview__c object |
| `FP_Request_Type__c` | Request Type | picklist | No | Values: Customer Nomination, Partner Nomination, Internal Request |
| `FP_Status__c` | Status | picklist | No | Values: Submitted, Approved, Rejected, Withdrawn |
| `Approval_Comments__c` | Approval Comments | textarea | No | 32768 chars max |
| `Customer_Use_Case__c` | Customer Use Case | textarea | No | 32768 chars max |
| `FP_Region__c` | Region | picklist | No | Values: AMER, APAC, EMEA, JAPAC |

### Picklist Values
**FP_Request_Type__c:**
- Customer Nomination
- Partner Nomination
- Internal Request

**FP_Status__c:**
- Submitted
- Approved
- Rejected
- Withdrawn

**FP_Region__c:**
- AMER
- APAC
- EMEA
- JAPAC

**CurrencyIsoCode:**
- USD (restricted)

## sf CLI Commands

### Create
```bash
# Basic create
sf data create record --sobject FP_Approval__c \
  --values "FP_Account__c=001XXXXXXXXXXXX FP_Request_Type__c='Customer Nomination'" \
  --json

# Create with multiple fields
sf data create record --sobject FP_Approval__c \
  --values "FP_Account__c=001XXXXXXXXXXXX FP_Opportunity__c=006XXXXXXXXXXXX \
  FP_Request_Type__c='Customer Nomination' FP_Status__c=Submitted \
  FP_Region__c=AMER Customer_Use_Case__c='Testing new ML features'" \
  --json

# Create with preview name reference
sf data create record --sobject FP_Approval__c \
  --values "FP_Preview_Name__c=a0BXXXXXXXXXXXX FP_Request_Type__c='Internal Request' \
  FP_Status__c=Submitted" \
  --json
```

### Read
```bash
# Get single record by ID
sf data get record --sobject FP_Approval__c --record-id a0CXXXXXXXXXXXX --json

# Query records with SOQL
sf data query --query "SELECT Id, Name, FP_Account__c, FP_Status__c, FP_Request_Type__c, CreatedDate FROM FP_Approval__c LIMIT 10" --json

# Query with relationships
sf data query --query "SELECT Id, Name, FP_Account__r.Name, FP_Opportunity__r.Name, FP_Status__c FROM FP_Approval__c WHERE FP_Account__c != null" --json

# Search by status
sf data query --query "SELECT Id, Name, FP_Account__r.Name, FP_Status__c FROM FP_Approval__c WHERE FP_Status__c = 'Submitted'" --json
```

### Update
```bash
# Update status
sf data update record --sobject FP_Approval__c --record-id a0CXXXXXXXXXXXX \
  --values "FP_Status__c=Approved" --json

# Update multiple fields
sf data update record --sobject FP_Approval__c --record-id a0CXXXXXXXXXXXX \
  --values "FP_Status__c=Approved Approval_Comments__c='Approved for Q1 rollout'" --json

# Update request type and region
sf data update record --sobject FP_Approval__c --record-id a0CXXXXXXXXXXXX \
  --values "FP_Request_Type__c='Partner Nomination' FP_Region__c=EMEA" --json
```

## Search Examples

### Common Query Patterns
```bash
# Submitted approvals for specific account
sf data query --query "SELECT Id, Name, FP_Status__c, CreatedDate FROM FP_Approval__c WHERE FP_Status__c = 'Submitted' AND FP_Account__c = '001XXXXXXXXXXXX'" --json

# Recent approvals by region
sf data query --query "SELECT Id, Name, FP_Account__r.Name, FP_Region__c, CreatedDate FROM FP_Approval__c WHERE FP_Region__c = 'AMER' AND CreatedDate = THIS_MONTH" --json

# All approved nominations
sf data query --query "SELECT Id, Name, FP_Account__r.Name, FP_Request_Type__c FROM FP_Approval__c WHERE FP_Status__c = 'Approved'" --json

# Count by status
sf data query --query "SELECT FP_Status__c, COUNT(Id) total FROM FP_Approval__c GROUP BY FP_Status__c" --json

# Approvals with opportunities
sf data query --query "SELECT Id, Name, FP_Opportunity__r.Name, FP_Status__c FROM FP_Approval__c WHERE FP_Opportunity__c != null" --json
```

## Notes
- Use `--json` flag for machine-readable output
- Use `--target-org` to specify org if multiple orgs configured
- `Name` field is auto-number and cannot be set manually
- Record IDs are 18 characters (15-char IDs also work)
- Use `sf sobject describe --sobject FP_Approval__c --json` for complete field metadata
- Related objects: FP_Activity__c, FP_Customer__c, FP_CustomerTeam__c, FP_Enrollment__c
