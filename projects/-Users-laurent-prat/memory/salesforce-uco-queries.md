# Salesforce UCO Query Patterns

## User: Laurent Prat
- **Salesforce User ID**: `0058Y00000C0P5ZQAV`
- **Email**: `laurent.prat@databricks.com`

## How to Retrieve Use Cases for This User

**IMPORTANT**: Do NOT use `OwnerId`, `Solution_Architect__c`, or `Primary_Solution_Architect__c` fields directly on UseCase__c to find user's UCOs.

### Correct Method: Query via Account.Last_SA_Engaged__c

The user's UCOs are associated through the **Account** object's `Last_SA_Engaged__c` field.

**Step 1: Get accounts where user is Last SA Engaged**
```bash
sf data query --query "SELECT Id, Name FROM Account WHERE Last_SA_Engaged__c = '0058Y00000C0P5ZQAV'" --json
```

**Step 2: Query UCOs for those accounts**
```bash
sf data query --query "SELECT Id, Name, Account__r.Name, Stages__c, Implementation_Status__c, Demand_Plan_Next_Steps__c, Full_Production_Date__c FROM UseCase__c WHERE Stages__c = 'U3' AND Account__c IN ('<account_ids>') ORDER BY Account__r.Name" --json
```

### Stage Filter Reference
- **U2**: Scoping
- **U3**: Evaluating
- **U4**: Confirming
- **U5**: Onboarding
- **U6**: Live
- **Active stages requiring SA tracking**: U2, U3, U4, U5

### Key Fields for UCO Updates
| Label | API Field |
|-------|-----------|
| Health Status | `Implementation_Status__c` (Red/Yellow/Green) |
| Next Steps | `Demand_Plan_Next_Steps__c` |
| Target Live Date | `Full_Production_Date__c` |
| Target Onboarding | `Implementation_Start_Date__c` |
| In Plan | `UseCaseInPlan__c` |

### Account SA Fields Reference
| Field | Label | Type |
|-------|-------|------|
| `Last_SA_Engaged__c` | Last SA Engaged | reference (User) |
| `CSE_New__c` | DSA | reference (User) |
| `Secondary_CSE__c` | Secondary DSA | reference (User) |

---

## UCO Weekly Hygiene Best Practices

### Time Constraint
- UCOs in **U2+ stages** must be updated **weekly** (within 7 days)
- Check `LastModifiedDate` or first line of `Demand_Plan_Next_Steps__c` to identify stale UCOs

### Next Steps Format (`Demand_Plan_Next_Steps__c`)
Prepend new updates to existing content. Format:
```
[Mon-DD] - [INITIALS] - Status: [On track/At Risk/Yellow]
Last: [What was completed]
Next: [Upcoming actions]
Risk: [None or describe risk]
```

Example:
```
Feb-11 - LP - Status: On track
Last: Monthly sync completed, migration on schedule.
Next: Follow up on production status next week.
Risk: None
```

### Quick Queries

**Find all active UCOs with subquery (single command):**
```bash
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, Account__r.Name, Demand_Plan_Next_Steps__c, LastModifiedDate FROM UseCase__c WHERE Account__c IN (SELECT Id FROM Account WHERE Last_SA_Engaged__c = '0058Y00000C0P5ZQAV') AND Stages__c IN ('U2', 'U3', 'U4', 'U5') ORDER BY Stages__c, Account__r.Name" --json
```

**Find UCOs missing health status:**
```bash
sf data query --query "SELECT Id, Name, Account__r.Name, Stages__c FROM UseCase__c WHERE Account__c IN (SELECT Id FROM Account WHERE Last_SA_Engaged__c = '0058Y00000C0P5ZQAV') AND Stages__c IN ('U2', 'U3', 'U4', 'U5') AND Implementation_Status__c = null" --json
```

### Update Commands

**Update Next Steps (prepend new entry):**
```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Demand_Plan_Next_Steps__c='<NEW_ENTRY>

<EXISTING_CONTENT>'"
```

**Set Health Status:**
```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Implementation_Status__c=Green"
```

### UCO Hygiene Checklist
1. Query all active UCOs (U2-U5)
2. Check for stale Next Steps (>7 days since last update)
3. Check for missing Health Status (Implementation_Status__c = null)
4. Draft and apply updates for stale UCOs
5. Set health status based on Next Steps status
6. **For U5 (Onboarding) UCOs**: Check documentation requirements (see below)

---

## U5 Onboarding Documentation Requirements

**IMPORTANT**: UCOs in **U5 (Onboarding)** stage require proper documentation attached.

### Required Document Fields
| Label | API Field | Purpose |
|-------|-----------|---------|
| Artifact Link | `Artifact_Link__c` | Link to onboarding artifacts/docs |
| POC Doc | `POC_Doc__c` | POC documentation |
| Sizing Sheet | `Sizing_Sheet_link__c` | Sizing/estimation sheet |
| Onboarding Plan | `Implementation_Notes__c` | Text description of onboarding plan |
| Onboarding Strategy | `Implementation_Strategy__c` | Self/Partner/PS implementation |

### Query U5 UCOs with Document Status
```bash
sf data query --query "SELECT Id, Name, Account__r.Name, Full_Production_Date__c, Artifact_Link__c, POC_Doc__c, Sizing_Sheet_link__c, Implementation_Notes__c, Implementation_Strategy__c FROM UseCase__c WHERE Account__c IN (SELECT Id FROM Account WHERE Last_SA_Engaged__c = '0058Y00000C0P5ZQAV') AND Stages__c = 'U5' ORDER BY Account__r.Name" --json
```

### U5 Documentation Checklist
1. Query all U5 UCOs
2. Check `Artifact_Link__c` is populated with onboarding doc link
3. Check `Implementation_Notes__c` has meaningful onboarding plan
4. Verify `Full_Production_Date__c` (Target Live Date) is set
5. Flag UCOs missing documentation for follow-up

### Update Artifact Link
```bash
sf data update record --sobject UseCase__c --record-id <UCO_ID> \
  --values "Artifact_Link__c='https://docs.google.com/document/d/xxx'"
```

---

## Associate Documents Section (IMPORTANT)

**CRITICAL**: The "Associate Documents" modal on UCO pages requires **manual entry through the UI**. Creating GoogleDoc records via API does NOT automatically populate this section.

### How Associate Documents Works
1. The modal presents 3 fixed document types:
   - **Eval Doc** - Evaluation documentation
   - **Exec Alignment** - Executive alignment documents
   - **Onboarding Doc** - Onboarding plan document (required for U5)

2. Each row has a "Document Link" field where you paste the Google Doc URL

3. **You MUST manually**:
   - Open the UCO in Salesforce
   - Click "Associate Documents" button
   - Paste the URL in the appropriate row (e.g., "Onboarding Doc")
   - Click Save

### What Does NOT Work
- Creating `GoogleDoc` records via SF CLI/API does not populate the modal
- Updating `Artifact_Link__c` field does not populate the modal
- The modal uses a custom Lightning component with its own data storage mechanism

### GoogleDoc Object (Reference Only)
The `GoogleDoc` standard object exists and stores document links:
```bash
# Query GoogleDoc records for a UCO
sf data query --query "SELECT Id, Name, Url, ParentId FROM GoogleDoc WHERE ParentId = '<UCO_ID>'" --json
```

Fields: `Id`, `Url`, `ParentId`, `Name`, `OwnerId`, `CreatedDate`, `LastModifiedDate`

**Note**: GoogleDoc records may be created by the modal when saving, but creating them via API does not make them appear in the modal.

### Workflow for U5 Onboarding Docs
1. Create the Google Doc (see [uco-onboarding-template.md](./uco-onboarding-template.md))
2. Share with databricks.com domain as VIEWER
3. **Set clickable link via API** - Update `Artifact_Link__c` field:
   ```bash
   sf data update record --sobject UseCase__c --record-id <UCO_ID> \
     --values "Artifact_Link__c='https://docs.google.com/document/d/<DOC_ID>/edit'"
   ```
   This displays as **"Onboarding Doc (Link)"** in MEDDPICC > Path to Production section (clickable!)

4. Optionally append link to Description field (`Use_Case_Description__c`) for copy-paste access

5. **Manually** open each UCO → Associate Documents → paste URL in "Onboarding Doc" row → Save

### Field Mapping for Documents
| UI Label | API Field | Location | Clickable? |
|----------|-----------|----------|------------|
| Onboarding Doc (Link) | `Artifact_Link__c` | MEDDPICC > Path to Production | Yes |
| Eval Doc (GDrive Link) | `POC_Doc__c` | MEDDPICC > Decision Criteria | Yes |
| Exec Alignment (GDrive Link) | TBD | MEDDPICC > Decision Process | Yes |
| Description | `Use_Case_Description__c` | Overview | No (plain text) |
| Business Problem Description | `Description__c` | Not on main layout | No |

---

## Debugging Lessons Learned (Feb 2026)

### Field Name Confusion
- **UI "Description" field** = `Use_Case_Description__c` (NOT `Description__c`)
- `Description__c` is labeled "Business Problem Description" and may not be on the page layout
- Always verify field API names by checking `sf sobject describe` output

### GoogleDoc Object Limitations
The `GoogleDoc` standard object exists but has severe limitations:
1. Creating GoogleDoc records via API does NOT populate the "Associate Documents" modal
2. The modal is a custom Lightning component with its own storage mechanism
3. GoogleDoc object only has basic fields: `Id`, `Url`, `ParentId`, `Name`, `OwnerId`, timestamps
4. No "Type" field on GoogleDoc - document type is NOT stored there

### What Works for Document Links
1. **`Artifact_Link__c`** - Best option! Displays as clickable "Onboarding Doc (Link)" in MEDDPICC
2. **`Use_Case_Description__c`** - Append link text for copy-paste (not clickable)
3. **Associate Documents modal** - Must be done manually through UI

### Shell Escaping Issues
When updating text fields with special characters (French accents, quotes):
- Use Python subprocess instead of direct shell commands
- Escape single quotes: `new_desc.replace("'", "\\'")`
- Or use double quotes and escape internal double quotes

### API vs UI Behavior
- Updating a field via API may not trigger the same UI refresh as manual edits
- Some Lightning components cache data and don't reflect API changes immediately
- "Touching" a record (updating any field) can help trigger refreshes
