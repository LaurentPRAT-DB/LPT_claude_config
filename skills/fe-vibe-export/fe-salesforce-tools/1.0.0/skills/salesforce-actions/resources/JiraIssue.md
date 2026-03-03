# JIRA Integration Objects

Salesforce integrates with JIRA through two objects: `Grz_Sf__JiraIssue__c` for JIRA issues and `Grz_Sf__JiraRelationship__c` as a junction object linking JIRA issues to Cases.

## Grz_Sf__JiraIssue__c (JIRA Issue)

Represents a JIRA issue synced to Salesforce.

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| Grz_Sf__IssueKey__c | string | JIRA issue key (e.g., ES-1234567, SUP-12345, BL-12345) |
| Grz_Sf__Summary__c | string | Issue summary/title |
| Grz_Sf__Description__c | textarea | Issue description |
| Grz_Sf__Status__c | string | JIRA status (Open, In Progress, Resolved, Closed, etc.) |
| Grz_Sf__Priority__c | string | Issue priority |
| Grz_Sf__Assignee__c | string | Assigned engineer |
| Grz_Sf__Reporter__c | string | Issue reporter |
| Grz_Sf__Jira_Link__c | url | Direct link to JIRA issue |
| Grz_Sf__Resolution__c | string | Resolution status |
| Grz_Sf__ResolutionDate__c | datetime | When resolved |
| Grz_Sf__Created__c | datetime | When created in JIRA |
| Grz_Sf__Updated__c | datetime | Last update in JIRA |
| Grz_Sf__IssueType__c | string | Issue type (Bug, Task, Story, etc.) |
| Grz_Sf__Project__c | string | JIRA project name |
| Grz_Sf__CaseNos__c | textarea | Case numbers (not filterable) |

## Grz_Sf__JiraRelationship__c (Junction Object)

Links JIRA issues to Salesforce Cases. **Use this object to find JIRA issues for specific Cases.**

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| Grz_Sf__JiraIssue__c | reference | Reference to JiraIssue__c |
| Grz_Sf__CaseRelation__c | reference | Reference to Case |
| Grz_Sf__AccountRelation__c | reference | Reference to Account |
| Grz_Sf__Jira_Issue_Link__c | url | Direct link to JIRA issue |

## CLI Commands

### Query JIRA Issues for Specific Cases

```bash
# Get JIRA issues linked to specific case IDs
sf data query --query "SELECT Grz_Sf__CaseRelation__r.CaseNumber, Grz_Sf__JiraIssue__r.Grz_Sf__IssueKey__c, Grz_Sf__JiraIssue__r.Grz_Sf__Summary__c, Grz_Sf__JiraIssue__r.Grz_Sf__Status__c, Grz_Sf__Jira_Issue_Link__c FROM Grz_Sf__JiraRelationship__c WHERE Grz_Sf__CaseRelation__c IN ('500xxxxxxxxxxxxxxx', '500xxxxxxxxxxxxxxx')"
```

### Query JIRA Issues for an Account's Cases

```bash
# First get Case IDs for the account
sf data query --query "SELECT Id, CaseNumber FROM Case WHERE AccountId = '001xxxxxxxxxxxxxxx' ORDER BY CreatedDate DESC LIMIT 10"

# Then query JIRA relationships for those case IDs
sf data query --query "SELECT Grz_Sf__CaseRelation__r.CaseNumber, Grz_Sf__JiraIssue__r.Grz_Sf__IssueKey__c, Grz_Sf__JiraIssue__r.Grz_Sf__Summary__c, Grz_Sf__JiraIssue__r.Grz_Sf__Status__c, Grz_Sf__Jira_Issue_Link__c FROM Grz_Sf__JiraRelationship__c WHERE Grz_Sf__CaseRelation__c IN ('case_id_1', 'case_id_2')"
```

### Query JIRA Issue Details

```bash
# Get details for a specific JIRA issue
sf data query --query "SELECT Id, Grz_Sf__IssueKey__c, Grz_Sf__Summary__c, Grz_Sf__Description__c, Grz_Sf__Status__c, Grz_Sf__Priority__c, Grz_Sf__Assignee__c, Grz_Sf__Jira_Link__c FROM Grz_Sf__JiraIssue__c WHERE Grz_Sf__IssueKey__c = 'ES-1234567'"
```

### Query Open JIRA Issues by Status

```bash
# Get all in-progress JIRA issues
sf data query --query "SELECT Grz_Sf__IssueKey__c, Grz_Sf__Summary__c, Grz_Sf__Assignee__c, Grz_Sf__Updated__c FROM Grz_Sf__JiraIssue__c WHERE Grz_Sf__Status__c = 'In Progress' ORDER BY Grz_Sf__Updated__c DESC LIMIT 20"
```

## Common JIRA Issue Prefixes

- **ES-** : Engineering Support tickets
- **SUP-** : Support tickets
- **BL-** : Backline tickets
- **SC-** : Other support categories

## Notes

- The `Grz_Sf__CaseNos__c` field on JiraIssue cannot be used in WHERE clauses
- Always use the junction object `Grz_Sf__JiraRelationship__c` to find JIRA-Case associations
- JIRA data is synced periodically; there may be slight delays in status updates
