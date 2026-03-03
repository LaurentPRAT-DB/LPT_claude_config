# Escalation_Request__c Object

## Overview
Custom Salesforce object for managing escalation requests. Auto-numbered with format ER-{00000}.

## Required Fields
- **OwnerId** (Reference to User/Group) - Auto-assigned to current user if not specified

## Key Fields

### Text Fields
- **Description_of_the_Request__c** (Long Text, 32000) - Escalation description
- **Customer_Impact__c** (Picklist) - Impact severity (Sev1, Sev2, etc.)
- **Escalation_type__c** (Picklist) - Type of escalation
- **Escalation_Status__c** (Picklist) - Current status
- **Escalation_Reason__c** (Picklist) - Reason for escalation
- **Closure_note__c** (Text) - Notes on closure
- **Root_cause__c** (Text) - Root cause analysis
- **Action_items_or_follow_up_actions__c** (Text) - Follow-up actions
- **Action_plan_and_Owners__c** (Text) - Action plan details
- **Exit_Criteria__c** (Text) - Criteria for closing escalation
- **Get_Well_Plan_status__c** (Picklist) - Recovery plan status
- **Recommendations__c** (Text) - Recommendations

### Reference Fields
- **Account__c** (Lookup to Account)
- **Initiator__c** (Lookup to User)
- **Executive_Sponsor__c** (Lookup to User)
- **CSE_Name__c** (Text) - CSE name
- **AE_Name__c** (Text) - AE name

### Date/Time Fields
- **Open_Date__c** (Date) - When escalation was opened
- **Resolution_Date__c** (Date) - When escalation was resolved
- **Escalation_Closed_Date__c** (Date) - When escalation was closed

### Other Fields
- **Region__c** (Picklist) - Region
- **Escalation_Channel__c** (Picklist) - Channel used
- **MSFT_Ticket__c** (Text) - Microsoft ticket reference
- **Incident_Sensitivity_Flag__c** (Boolean) - Sensitivity flag

### System Fields (Read-only)
- **Id** - Record ID
- **Name** - Auto-number (ER-{00000})
- **CreatedDate**, **CreatedById**
- **LastModifiedDate**, **LastModifiedById**

## Fields That Do NOT Exist

**IMPORTANT**: The following field names do NOT exist on the Escalation_Request__c object. Do not use them in queries:
- `Next_Steps__c` - Does not exist. Use `Action_items_or_follow_up_actions__c` or `Action_plan_and_Owners__c` for next steps information.
- `Stakeholder_Update__c` - Use `Stakeholders_Update__c` (note the 's' in Stakeholders)

## Relationship Field Issues

**IMPORTANT**: Some relationship queries may not work as expected:
- `Initiator__r` - This relationship query does not work reliably. The `Initiator__c` field exists, but querying through the relationship (e.g., `Initiator__r.Name`) may fail.
  - ✓ **Use instead**: Query `CreatedBy.Name` and `Owner.Name` to identify who initiated and who is handling the escalation.
  - ✓ **Example**: `SELECT Id, Name, CreatedBy.Name, CreatedBy.Email, Owner.Name, Owner.Email FROM Escalation_Request__c`

## Related Objects

### Escalation_Request_Summary__c (Junction Object)
Links Escalation Requests to Cases. Use this to find which Cases are associated with an escalation.

| Field | Type | Description |
|-------|------|-------------|
| Escalation_Request__c | reference | Reference to Escalation_Request__c |
| Case__c | reference | Reference to Case |
| Backline_Escalation__c | reference | Reference to Backline_Escalation__c |
| Escalation_Request_Status__c | string | Status from the escalation |
| Escalation_Request_Owner__c | string | Owner from the escalation |

## CLI Commands

### Create Record
```bash
sf data create record --sobject Escalation_Request__c \
  --values "Escalation_type__c='Technical' Escalation_Status__c='Open' Description_of_the_Request__c='Issue description'"
```

### Query Records
```bash
# Get all open escalations with action info
sf data query --query "SELECT Id, Name, Escalation_Status__c, Escalation_type__c, Customer_Impact__c, Description_of_the_Request__c, Action_plan_and_Owners__c, CreatedDate FROM Escalation_Request__c WHERE Escalation_Status__c != 'Closed' ORDER BY CreatedDate DESC"

# Get by specific ID with full details
sf data query --query "SELECT Id, Name, Escalation_Status__c, Escalation_type__c, Description_of_the_Request__c, Customer_Impact__c, Action_plan_and_Owners__c, Stakeholders_Update__c FROM Escalation_Request__c WHERE Id = 'aLT...' LIMIT 1"

# Get by account
sf data query --query "SELECT Id, Name, Escalation_Status__c, Escalation_type__c, Description_of_the_Request__c FROM Escalation_Request__c WHERE Account__c = '001...' ORDER BY CreatedDate DESC"

# Get escalations with linked Cases (via junction object)
sf data query --query "SELECT Escalation_Request__r.Name, Escalation_Request__r.Escalation_Status__c, Escalation_Request__r.Escalation_type__c, Escalation_Request__r.Description_of_the_Request__c, Escalation_Request__r.Action_plan_and_Owners__c, Case__r.CaseNumber, Case__r.Subject, Case__r.Status FROM Escalation_Request_Summary__c WHERE Escalation_Request__r.Account__c = '001xxxxxxxxxxxxxxx' ORDER BY Escalation_Request__r.CreatedDate DESC LIMIT 10"
```

### Update Record
```bash
# Update status
sf data update record --sobject Escalation_Request__c \
  --record-id aLT... \
  --values "Escalation_Status__c='In Progress'"

# Update multiple fields
sf data update record --sobject Escalation_Request__c \
  --record-id aLT... \
  --values "Escalation_Status__c='Closed' Resolution_Date__c='2025-10-28' Closure_note__c='Issue resolved'"
```

## Picklist Values

### Escalation_type__c
- Technical
- Customer Success Escalation
- Executive Escalation
- Incident Escalation
- Product Escalation
- Support Escalation

### Escalation_Status__c
- Open
- In Progress
- Closed
- Resolved

### Customer_Impact__c
- Sev1
- Sev2
- Sev3
- Sev4
