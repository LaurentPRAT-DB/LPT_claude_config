# Blocker Object

The `Blocker__c` object tracks issues that block or create friction for customer adoption and deal progression.

## Required Fields

- **Use_Case__c** (reference to UseCase__c)

## Field Reference

### Core Fields

| Field API Name | Label | Type | Required | Default | Description |
|----------------|-------|------|----------|---------|-------------|
| Use_Case__c | Use Case | reference | Yes | - | Reference to UseCase__c object |
| Type__c | Type | picklist | No | - | Blocked or Friction |
| Blocker_Status__c | Blocker Status | picklist | No | Open | Open, In Progress, or Closed |
| Category__c | Category | picklist | No | - | Blocker category |
| Comment__c | Comment | textarea | No | - | Additional details |
| DBU_Blocked__c | $DBU Blocked | currency | No | - | Dollar value of blocked DBUs |
| Blocker_Close_Date__c | Blocker Close Date | datetime | No | - | When blocker was closed |
| Account__c | Account | reference | No | - | Reference to Account |
| Aha_Idea__c | Aha! Idea | reference | No | - | Reference to ahaapp__AhaIdea__c |
| Aha_Status__c | Aha Status | string | No | - | Status of linked Aha Idea |
| Use_Case_Name__c | Use Case Name | string | No | - | Formula field with Use Case name |

### Use Case Relationship Fields
When querying, you can access related Use Case fields via the `Use_Case__r` relationship:
- `Use_Case__r.Name` - Use Case name
- `Use_Case__r.Description__c` - Use Case description
- `Use_Case__r.Status__c` - Use Case status
- `Use_Case__r.Account__r.Name` - Account name from Use Case

### Picklist Values

**Type__c**: Blocked, Friction
- Blocked: Customer can't adopt or move forward
- Friction: Missing feature is slowing down the deal

**Blocker_Status__c**: Open, In Progress, Closed

**Category__c**: C&SI Partner, Cloud Partner, Customer Blocker (unrelated to Databricks), Customer Buy-In, Implementation, Legal, Migration not planned anytime soon, Operating Cost, Other, Product (Aha features, bugs, etc.), Security / Compliance

## Fields That Do NOT Exist

**IMPORTANT**: The following field names do NOT exist on the Blocker__c object. Do not use them in queries:
- `Aha_Idea_Link__c` - Does not exist. To get AHA Idea URLs, query the linked `ahaapp__AhaIdea__c` object using the `Aha_Idea__c` reference ID and get the `ahaapp__ReferenceNum__c` field to construct the URL (e.g., `https://databricks.aha.io/ideas/DB-I-XXXXX`).

## CLI Commands

### Create a Blocker

```bash
sf data create record --sobject Blocker__c \
  --values "Use_Case__c='<UseCase_ID>' Type__c='Blocked' Blocker_Status__c='Open' Category__c='Product (Aha features, bugs, etc.)' Comment__c='Description of blocker'"
```

### Query Blockers

```bash
# Get all open blockers with Use Case details
sf data query --query "SELECT Id, Name, Type__c, Blocker_Status__c, Category__c, Comment__c, Use_Case__r.Name, Use_Case__r.Description__c FROM Blocker__c WHERE Blocker_Status__c = 'Open'"

# Get blockers by Use Case
sf data query --query "SELECT Id, Name, Type__c, Blocker_Status__c, Category__c, Comment__c FROM Blocker__c WHERE Use_Case__c = '<UseCase_ID>'"

# Get blockers with related Use Case and Aha Idea info
sf data query --query "SELECT Id, Name, Type__c, Blocker_Status__c, Comment__c, Use_Case__r.Name, Use_Case__r.Description__c, Aha_Idea__c, Aha_Status__c FROM Blocker__c WHERE Blocker_Status__c IN ('Open', 'In Progress')"

# Get blockers for an account with full context
sf data query --query "SELECT Id, Name, Type__c, Blocker_Status__c, Category__c, Comment__c, Use_Case__r.Name, Aha_Idea__c, CreatedDate FROM Blocker__c WHERE Account__c = '001xxxxxxxxxxxxxxx' ORDER BY CreatedDate DESC LIMIT 10"
```

### Update a Blocker

```bash
# Update status
sf data update record --sobject Blocker__c \
  --record-id <Blocker_ID> \
  --values "Blocker_Status__c='In Progress'"

# Close a blocker
sf data update record --sobject Blocker__c \
  --record-id <Blocker_ID> \
  --values "Blocker_Status__c='Closed' Blocker_Close_Date__c='2025-10-28T12:00:00Z'"

# Update multiple fields
sf data update record --sobject Blocker__c \
  --record-id <Blocker_ID> \
  --values "Type__c='Friction' Category__c='Security / Compliance' DBU_Blocked__c=50000"
```
