# ApprovalRequest__c

Custom Salesforce object for managing approval requests.

## Required Fields for Creation

- **OwnerId** (reference) - Owner of the record (User or Group ID)

## Key Fields

### Core Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| Name | string | No | Auto-number field (auto-generated) |
| OwnerId | reference | Yes | User or Group ID |
| RecordTypeId | reference | No | Record Type ID |
| CurrencyIsoCode | picklist | No | Default: USD |

### Status & Tracking

| Field | Type | Picklist Values |
|-------|------|-----------------|
| Status__c | picklist | New, In Progress, Complete, Unassigned, Assigned, Ready to Assign, On Hold, Draft, Delivered, Pipeline, Enrolled, SCP Incubator, SCP, Relegated, Review Pending, Review In Progress, Approved, Rejected, Additional Details Required, etc. |
| ApprovalStatus__c | picklist | L1 reviewing, L2 reviewing, L3 reviewing, L3 approved, L4 reviewing, L4 approved, L5 reviewing, L5 approved |
| Request_Type__c | picklist | Workshops, Specialist SA Request, Product Specialists, Security, FieldServices, Competitive Intelligence, etc. |

### Key Reference Fields

| Field | Type | Description |
|-------|------|-------------|
| Account__c | reference | Related Account |
| Opportunity__c | reference | Related Opportunity |
| Case__c | reference | Related Case |
| Requestor__c | reference | User who requested |
| Customer_Contact__c | reference | Customer contact (Contact) |

### Important Text/URL Fields

| Field | Type | Description |
|-------|------|-------------|
| Request_Description__c | textarea | Request description |
| Situation_Details__c | textarea | Specific initiatives |
| Additional_Comments__c | textarea | Additional comments |
| JIRA_link__c | url | JIRA link |
| Opportunity_Background__c | url | Opportunity background link |

### Boolean Flags (all default to false)

Common boolean fields include:
- CustomerPartnerCoFundingInvestment__c
- Demand_Capacity_plan__c
- Enablement_Plan_Completed__c
- Security_Cleared__c
- Workspace_Deployed__c

## CLI Commands

### Create a Record

```bash
sf data create record -s ApprovalRequest__c -v "OwnerId=<USER_OR_GROUP_ID> Status__c='Draft' Request_Type__c='Workshops' Request_Description__c='Sample request'"
```

### Query Records

```bash
# Query all fields
sf data query -q "SELECT Id, Name, Status__c, Request_Type__c, OwnerId FROM ApprovalRequest__c LIMIT 10"

# Query by status
sf data query -q "SELECT Id, Name, Status__c, Request_Description__c FROM ApprovalRequest__c WHERE Status__c = 'Draft'"

# Query by approval status
sf data query -q "SELECT Id, Name, ApprovalStatus__c, Status__c FROM ApprovalRequest__c WHERE ApprovalStatus__c = 'L1 reviewing'"

# Query with related fields
sf data query -q "SELECT Id, Name, Account__r.Name, Opportunity__r.Name FROM ApprovalRequest__c WHERE Account__c != null"
```

### Update a Record

```bash
# Update single field
sf data update record -s ApprovalRequest__c -i <RECORD_ID> -v "Status__c='In Progress'"

# Update multiple fields
sf data update record -s ApprovalRequest__c -i <RECORD_ID> -v "Status__c='Complete' ApprovalStatus__c='L3 approved' Request_Status_Notes__c='Approved and ready'"
```

## Notes

- Name field is auto-generated (auto-number)
- CurrencyIsoCode defaults to USD
- Most fields are optional except OwnerId
- Object supports record types via RecordTypeId
- Object is not deletable (deletable=false)
