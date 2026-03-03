# Workspace__c Object

Custom Salesforce object representing Databricks workspaces.

## Required Fields

- **Name** (string, max 80 chars) - Workspace identifier

## Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `Id` | id | Record ID (auto-generated) |
| `Name` | string | Workspace name (required, max 80 chars) |
| `OwnerId` | reference | Owner ID (User or Group) |
| `CurrencyIsoCode` | picklist | Currency code (default: USD) |
| `CreatedDate` | datetime | Record creation timestamp (auto-generated) |
| `CreatedById` | reference | User who created the record |
| `LastModifiedDate` | datetime | Last modification timestamp (auto-generated) |
| `LastModifiedById` | reference | User who last modified the record |
| `Account__c` | reference | Related Account |
| `Billing_Contract__c` | reference | Related billing contract |
| `Dedicated_Trial__c` | boolean | Whether this is a dedicated trial |
| `Expected_MRR__c` | currency | Expected monthly recurring revenue |
| `Intended_Use_Case__c` | textarea | Description of intended use case |
| `Opportunity__c` | reference | Related Opportunity |
| `Region__c` | picklist | Workspace region |
| `Shard_Name__c` | string | Shard identifier (unique, external ID, max 255 chars) |
| `Status__c` | picklist | Workspace status |
| `Tier__c` | picklist | Workspace tier/edition |
| `Trial_End_Date__c` | date | Trial expiration date |
| `Trial_Start_Date__c` | date | Trial start date |
| `Workspace_ID__c` | string | External workspace ID (max 255 chars) |
| `Workspace_URL__c` | url | Workspace URL |

## Picklist Values

**Region__c**: us-east-1, us-west-2, eu-west-1, ap-southeast-1, ap-southeast-2, ap-northeast-1, ca-central-1, eu-central-1

**Status__c**: Active, Inactive, Trial, Pending, Disabled

**Tier__c**: Standard, Premium, Enterprise

**CurrencyIsoCode**: USD (only)

## CLI Operations

### Query Records (SOQL)

```bash
# Get all workspaces
sf data query --query "SELECT Id, Name, Shard_Name__c, Status__c FROM Workspace__c"

# Find by shard name
sf data query --query "SELECT Id, Name, Account__c, Status__c FROM Workspace__c WHERE Shard_Name__c = 'my-shard'"

# Get workspace with related account
sf data query --query "SELECT Id, Name, Account__r.Name, Opportunity__r.Name FROM Workspace__c WHERE Id = '001XXXXXXXXXXXX'"

# Filter by status and date
sf data query --query "SELECT Id, Name, Status__c, Trial_End_Date__c FROM Workspace__c WHERE Status__c = 'Trial' AND Trial_End_Date__c >= TODAY"
```

### Create Records

```bash
# Basic workspace creation
sf data create record --sobject Workspace__c --values "Name='My Workspace' Shard_Name__c='my-workspace-shard'"

# Workspace with account and trial dates
sf data create record --sobject Workspace__c --values "Name='Trial Workspace' Account__c='001XXXXXXXXXXXX' Status__c='Trial' Trial_Start_Date__c='2024-01-01' Trial_End_Date__c='2024-02-01'"

# Workspace with all common fields
sf data create record --sobject Workspace__c --values "Name='Production WS' Shard_Name__c='prod-shard-123' Account__c='001XXXXXXXXXXXX' Status__c='Active' Tier__c='Enterprise' Region__c='us-east-1' Workspace_URL__c='https://workspace.databricks.com'"
```

### Update Records

```bash
# Update status by ID
sf data update record --sobject Workspace__c --record-id 'a0PXXXXXXXXXXXX' --values "Status__c='Active'"

# Update multiple fields
sf data update record --sobject Workspace__c --record-id 'a0PXXXXXXXXXXXX' --values "Status__c='Active' Tier__c='Premium' Expected_MRR__c=5000"

# Update using external ID (Shard_Name__c)
sf data update record --sobject Workspace__c --where "Shard_Name__c='my-shard'" --values "Status__c='Disabled'"
```

### Get Single Record

```bash
# Get record by ID
sf data get record --sobject Workspace__c --record-id 'a0PXXXXXXXXXXXX'

# Get specific fields
sf data get record --sobject Workspace__c --record-id 'a0PXXXXXXXXXXXX' --json | jq '.result | {Name, Status__c, Shard_Name__c}'
```

## Notes

- This object is read-only through standard API (createable: false, deletable: false)
- Use integration user or specialized permissions for CRUD operations
- `Shard_Name__c` is a unique external ID field useful for upsert operations
- Related objects: Account, Opportunity, Order_Subscription__c, Usage__c, Workspace_User__c
