# Case Object

Standard Salesforce object for tracking customer support cases and issues.

## Required Fields

- **BusinessHoursId** (reference): Business Hours ID - Must reference a valid BusinessHours record

## Key Fields

### Core Fields
- **Subject** (string): Case title/summary
- **Description** (textarea): Detailed case description
- **Status** (picklist): Case status (default: "New")
- **Priority** (picklist): Case priority (default: "Normal")
- **Origin** (picklist): Source of the case

### Relationships
- **AccountId** (reference): Account ID - Links to Account object
- **ContactId** (reference): Contact ID - Links to Contact object
- **OwnerId** (reference): Owner ID - Links to User or Group
- **ParentId** (reference): Parent Case ID - Links to parent Case

### Contact Information (Web-to-Case)
- **SuppliedName** (string): Submitter name
- **SuppliedEmail** (email): Submitter email
- **SuppliedPhone** (string): Submitter phone
- **SuppliedCompany** (string): Submitter company

### Progress/History Fields
- **Latest_Public_Comment__c** (textarea): Most recent public comment content
- **LastPublicComment_DateTime__c** (datetime): When the last public comment was made
- **CommentCount__c** (number): Total number of comments on the case
- **LastInternalComment_DateTime__c** (datetime): When the last internal comment was made
- **Next_Interaction_Date__c** (date): Next scheduled interaction date

### JIRA Integration
Cases can be linked to JIRA issues through the junction object `Grz_Sf__JiraRelationship__c`. See **JiraIssue.md** for details on querying JIRA issues linked to cases.

## Fields That Do NOT Exist

**IMPORTANT**: The following field names do NOT exist on the Case object. Do not use them in queries:
- `Slack_Thread__c` - Does not exist. There is no direct Slack thread link on Cases.
- `Backline_Tickets__c` - Does not exist. Use the JIRA integration via `Grz_Sf__JiraRelationship__c` junction object to find associated tickets (including Backline tickets which are tracked as JIRA issues with keys starting with "BL-").

## Picklist Values

### Status
New (default), Open, Pending, Awaiting Customer Response, On Hold, Escalated, Solved, In process, In Review, Responded, Pending - Sales, Pending - Legal, Pending - Finance, Pending - Order Mgmt, Pending - Billing, Pending - Deal Desk, Pending - Approval, Pending - IT, Closed, Re-Opened, Rejected, Closure Requested, Resolved RCA Pending, Solution Provided Awaiting Confirmation, Awaiting, Sent to SAP

### Priority
Low, Normal (default), High, Urgent, Priority 1, Priority 2, Priority 3, P1, P2, P3, Mission Critical

### Origin
Email, Phone, Web, Training Email, CS Email, Billing, Order Management, CIP, Playbook Import, CSE Request-Internal, ASQ Request-Internal, ac, workspace, bricky, lakesense, SupportHub, AskSupport, Jira, Support Automation, DFM, Merlin - Assistant, Merlin - No Assistant, SAP Resolve, Training Ops Email, Partner Training Ops Email, Neon App, Neon Manual

### Type
Problem, Feature Request, Question, Customer Success, Training, Billing, Order Management, Databricks Academy Access, Curriculum/Course Content, Certifications, Complimentary Live Training Events, Paid Instructor-led Training, Partner Training, Other, Finance Deal Approvals, Lab Feedback/Issues, Deal Desk, Support Admin, Neon, Neon Billing

### Reason
User didn't attend training, Complex functionality, Existing problem, Instructions not clear, New problem, Duplicate, Spam

## Examples

### Create a Case (POST)
```bash
# Simple case with minimum required fields
sf data create record --sobject Case --values "BusinessHoursId=01m61000000ABCDEF Subject='Login Issue' Description='Customer cannot access workspace'"

# Web-to-Case with supplied contact info
sf data create record --sobject Case --values "BusinessHoursId=01m61000000ABCDEF Subject='Performance Issue' SuppliedName='John Doe' SuppliedEmail='john@example.com' Status=New Priority=High Origin=Web"

# Case linked to Account and Contact
sf data create record --sobject Case --values "BusinessHoursId=01m61000000ABCDEF AccountId=001xxxxxxxxxxxxxxx ContactId=003xxxxxxxxxxxxxxx Subject='Feature Request' Type='Feature Request' Status=New"
```

### Query Cases (GET)
```bash
# Get all open cases
sf data query --query "SELECT Id, CaseNumber, Subject, Status, Priority FROM Case WHERE IsClosed = false"

# Get cases by status
sf data query --query "SELECT Id, CaseNumber, Subject, Status, Owner.Name FROM Case WHERE Status = 'Open'"

# Get high priority cases for specific account
sf data query --query "SELECT Id, CaseNumber, Subject, Priority, Status, Account.Name FROM Case WHERE AccountId = '001xxxxxxxxxxxxxxx' AND Priority IN ('High', 'Urgent')"

# Get case with related information
sf data query --query "SELECT Id, CaseNumber, Subject, Status, Priority, Account.Name, Contact.Email, Owner.Name FROM Case WHERE Id = '500xxxxxxxxxxxxxxx'"

# Get cases with progress/update information
sf data query --query "SELECT Id, CaseNumber, Subject, Status, Priority, Latest_Public_Comment__c, LastPublicComment_DateTime__c, CommentCount__c FROM Case WHERE AccountId = '001xxxxxxxxxxxxxxx' ORDER BY CreatedDate DESC LIMIT 5"

# Get JIRA issues linked to specific cases (use junction object)
sf data query --query "SELECT Grz_Sf__CaseRelation__r.CaseNumber, Grz_Sf__JiraIssue__r.Grz_Sf__IssueKey__c, Grz_Sf__JiraIssue__r.Grz_Sf__Summary__c, Grz_Sf__JiraIssue__r.Grz_Sf__Status__c, Grz_Sf__Jira_Issue_Link__c FROM Grz_Sf__JiraRelationship__c WHERE Grz_Sf__CaseRelation__c IN ('500xxxxxxxxxxxxxxx')"
```

### Update a Case (PATCH)
```bash
# Update case status
sf data update record --sobject Case --record-id 500xxxxxxxxxxxxxxx --values "Status=In process"

# Update priority and owner
sf data update record --sobject Case --record-id 500xxxxxxxxxxxxxxx --values "Priority=High OwnerId=005xxxxxxxxxxxxxxx"

# Update multiple fields
sf data update record --sobject Case --record-id 500xxxxxxxxxxxxxxx --values "Status=Solved Subject='Updated: Performance Issue - Resolved' Priority=Normal"
```
