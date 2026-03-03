# UseCase Salesforce Object

Custom object for tracking customer use cases. Links to accounts and opportunities for managing use case lifecycle and migration tracking.

## Configuration

- **Active Stages** (require SA tracking): U2, U3, U4, U5
- **Default Query Filter**: Always include `AND Stages__c IN ('U2', 'U3', 'U4', 'U5')` when querying for active UCOs

## Required Fields

**Name** (string, max 80 chars) - Use case identifier

## Common Fields

| Field | Type | Picklist Values | Notes |
|-------|------|-----------------|-------|
| Name | string(80) | - | |
| Account__c | reference (Account) | - | |
| Opportunity__c | reference (Opportunity) | - | |
| Status__c | picklist | Red, Yellow, Green | **RARELY POPULATED** - Use `Implementation_Status__c` instead |
| Active__c | boolean | - | |
| Is_Migration__c | boolean | - | |
| Priority__c | picklist | - | |
| Description__c | textarea (32,768) | - | **RARELY POPULATED** - Use `Use_Case_Description__c` instead |
| NextSteps__c | textarea | - | **RARELY POPULATED** - Use `Demand_Plan_Next_Steps__c` instead |
| Stages__c | picklist | U1, U2, U3, U4, U5, U6, Lost, Disqualified | **PRIMARY STAGE FIELD** - UCO lifecycle stage |
| Implementation_Status__c | picklist | Red, Yellow, Green | **PRIMARY STATUS FIELD** - Use this for status tracking |
| Solution_Architect__c | reference (User) | - | |
| Primary_Solution_Architect__c | reference (User) | - | |

## Commonly Used Fields vs Legacy Fields

**IMPORTANT**: When querying for use case details, prefer these actively populated fields:

### For Status Information
- ✓ **Use**: `Implementation_Status__c` (Red, Yellow, Green)
- ✗ **Avoid**: `Status__c` (exists but rarely populated)

### For Description/Details
- ✓ **Use**: `Use_Case_Description__c` (contains actual business description)
- ✗ **Avoid**: `Description__c` (exists but rarely populated)

### For Next Steps/Progress
- ✓ **Use**: `Demand_Plan_Next_Steps__c` (contains detailed progress updates)
- ✗ **Avoid**: `NextSteps__c` (exists but rarely populated)

### Additional Useful Fields
- `Implementation_Notes__c` - Implementation details and progress
- `Business_Value__c` - Business value description
- `Monthly_DBUs__c` - Monthly DBU consumption
- `Project_Name__c` - Associated project name

### Stage Fields Reference

Multiple stage-related fields exist. Here's which to use:

| Field | Values | Usage | Notes |
|-------|--------|-------|-------|
| **Stages__c** | U1, U2, U3, U4, U5, U6, Lost, Disqualified | **PRIMARY** - UCO lifecycle stage | Always use this for stage queries |
| DemandPlanStage__c | Existing, Validated, Potential | Demand planning maturity | Supplementary tracking |
| Implementation_Stage__c | Not Started, In Scoping, In Progress, Finished, On Hold | Implementation progress | Supplementary tracking |
| GTM_Stage__c | WIP, Engaged, Migration completed, Q/O - M&A, Q/O - Child entity, Q/O - Oppty Lost, Q/O - Other, No AE assigned | Go-to-market stage | **RARELY USED** - often null |
| Lifecycle_Stage__c | Implementation, Production, Interest, On Hold / Blocked, Not Interested, Inactive | High-level lifecycle | **RARELY USED** - often null |

**Key insight**: When querying for active UCOs, use `Stages__c IN ('U2', 'U3', 'U4', 'U5')` (SA tracking stages).

### Stage Tracking Metadata Fields
- `CurrentStageDaysCount__c` - Number of days in current stage
- `Last_Stage_Modified_Date__c` - When stage was last changed
- `Last_Stage_Modified_By__c` - Who last modified the stage
- `Stage_Numeric__c` - Numeric representation of stage

---

## UCO Weekly Update Fields (AMER Emerging)

**Reference Doc**: [UCO Management - AMER Emerging](https://docs.google.com/document/d/1cLx2xjQ8YqdxvJeFRIi3Z20xPgnaD-Mu_RNEKdzT8oM)

UCOs should be reviewed weekly and the following fields updated for UCOs in U2+:

| Document Field | API Field | Label | Type | Owner | Notes |
|----------------|-----------|-------|------|-------|-------|
| **Next Steps** | `Demand_Plan_Next_Steps__c` | "Next Steps" | textarea | AE | Format: Date/Initials, Current State, Next Steps, Risks |
| **Target Onboarding Date** | `Implementation_Start_Date__c` | "Target Onboarding Date" | date | AE | Date dev work begins & $DBU usage starts |
| **Target Live Date** | `Full_Production_Date__c` | "Target Live Date" | date | AE | Date dev work completes & $DBU at steady state |
| **Use Case Health** | `Implementation_Status__c` | "Manual Health Flag" | picklist | SA | Red/Yellow/Green - confidence in hitting Target Live Date |
| **Implementation Notes** | `Implementation_Notes__c` | "Onboarding Plan" | textarea | AE | Template: Enablement needed, Team engaged, Contact info |
| **In Plan vs Out of Plan** | `UseCaseInPlan__c` | "Use Case In Plan" | boolean | AE | Treat like "Forecast Category" - risk = Out of Plan |
| **DSA** | `DSA__c` | "DSA" | reference | DSA | DSA assigned to UCO |
| **Stage** | `Stages__c` | "Stage" | picklist | - | U1-U6 lifecycle stage |
| **Account Notes** | `ManagerNotes__c` | "Manager Notes" | textarea | FLM | **OPTIONAL - Managers only.** For high potential accounts, put "High Potential Accounts" on first line. Label each UCO's notes for accounts with multiple UCOs. |

### Stage Definitions (Stages__c)

| Stage | Name | Definition | Clear Indicator |
|-------|------|------------|-----------------|
| U2 | Scoping | Pain identified, willingness to address | Customer willing to engage with SA |
| U3 | Evaluating | Customer agrees DB could be solution. Requires: (1) Success criteria, (2) Workspace deployed, (3) Customer hands-on | Pilot/POC started |
| U4 | Confirming | Customer agrees DB is best solution | Tech Win from customer |
| U5 | Onboarding | Starting to use DBUs for this UCO | UCO driving $DBUs outside Pilot/POC |
| U6 | Live | Dev work completed, hitting MRR target | $DBU at steady state |

### Next Steps Format (Demand_Plan_Next_Steps__c)

Updates are **prepended** to the top (newest first). Each entry follows the **4-line template**:

```
[Mon-DD] - [INITIALS] - Status: [On track / At risk / On Hold]
Last: [What happened]
Next: [What's the next step]
Risk: [Any risks, or "None"]
```

**Example** (newest entries at top):
```
Feb-25 - LP - Status: On Hold
Last: Prepared champion recovery talking points doc. Coordinating with Laurie (Global AE).
Next: Schedule call with Jorg to identify new champion for fleet ML initiatives.
Risk: Deprioritization without new champion

Feb-18 - LB - Status: On Hold
Last: Lost internal champion Timo who left MSC.
Next: Need to identify new champion - Call with Jorg (Manager) in order to redefine the UC team.
Risk: Deprioritisation

Feb-11 - LP - Status: On track
Last: Monthly cadence call today. MSC 101 Handover completed.
Next: Continue predictive maintenance work. Next sync Feb 17.
Risk: None
```

#### CRITICAL RULES

1. **NEVER remove previous entries** - Always preserve the full history when updating
2. **Always query existing content first** - Read current `Demand_Plan_Next_Steps__c` before updating
3. **Prepend new entry** - Add new entry at the top, keeping all previous entries below
4. **Use 4-line format** - Each entry must have: Date/Initials/Status, Last, Next, Risk

#### Format Details

- **Date**: Use `Mon-DD` format (e.g., `Jan-05`, `Feb-25`)
- **Initials**: Your initials (e.g., `LP` for Laurent Prat)
- **Status**: On track, At risk, On Hold, Qualification ongoing, etc.
- **Last**: What happened since last update
- **Next**: What's the next action
- **Risk**: Any risks identified, or "None"

### Implementation Notes Template (Implementation_Notes__c)

```
Enablement needed: Y/N
Enablement team engaged: Y/N
Implementation Contact: <name>
- Self Implementation: customer contact who owns project
- Partner Implementation: partner contact who owns project
- PS Implementation: PS adds note
```

## Create

```bash
# Minimal create
sf data create record --sobject UseCase__c \
  --values "Name='Analytics Platform'"

# With account and status
sf data create record --sobject UseCase__c \
  --values "Name='Migration Project' Account__c=001XXXXXXXXXXXX \
  Status__c=Green Active__c=true Is_Migration__c=true"
```

## Read

```bash
# Get by ID
sf data get record --sobject UseCase__c --record-id a0AXXXXXXXXXXXX

# Query active use cases
sf data query --query "SELECT Id, Name, Implementation_Status__c, Account__r.Name FROM UseCase__c WHERE Active__c = true"

# Query by account (active stages only)
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c FROM UseCase__c WHERE Account__c = '001XXXXXXXXXXXX' AND Stages__c IN ('U2', 'U3', 'U4', 'U5')"

# Search by name
sf data query --query "SELECT Id, Name FROM UseCase__c WHERE Name LIKE '%Analytics%'"

# Query UCOs in active stages not updated in 7+ days (find stale UCOs)
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, LastModifiedDate \
  FROM UseCase__c \
  WHERE Account__c = '001XXXXXXXXXXXX' \
  AND Stages__c IN ('U2', 'U3', 'U4', 'U5') \
  AND LastModifiedDate < 2025-12-29T00:00:00Z \
  ORDER BY Stages__c, LastModifiedDate ASC"

# Count UCOs by stage for an account
sf data query --query "SELECT Stages__c, COUNT(Id) FROM UseCase__c WHERE Account__c = '001XXXXXXXXXXXX' GROUP BY Stages__c"
```

## Update

```bash
# Update status
sf data update record --sobject UseCase__c --record-id a0AXXXXXXXXXXXX \
  --values "Status__c=Red"

# Update multiple fields
sf data update record --sobject UseCase__c --record-id a0AXXXXXXXXXXXX \
  --values "Name='Updated Name' Active__c=false Priority__c=High"
```

## UCO Weekly Update Commands

These commands update the fields required for weekly UCO reviews (U2+ UCOs):

```bash
# Get current UCO state (all weekly update fields)
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, \
  Demand_Plan_Next_Steps__c, Implementation_Start_Date__c, Full_Production_Date__c, \
  Implementation_Notes__c, UseCaseInPlan__c, DSA__c, DSA__r.Name, ManagerNotes__c, \
  Account__r.Name FROM UseCase__c WHERE Id = 'aAvXXXXXXXXXXXXXXX'"

# Query all UCOs for an account that need weekly updates (active SA stages)
sf data query --query "SELECT Id, Name, Stages__c, Implementation_Status__c, \
  Demand_Plan_Next_Steps__c, Full_Production_Date__c \
  FROM UseCase__c \
  WHERE Account__c = '001XXXXXXXXXXXX' \
  AND Stages__c IN ('U2', 'U3', 'U4', 'U5') \
  AND Active__c = true"

# --- INDIVIDUAL FIELD UPDATES ---

# Update Next Steps - MUST preserve history with 4-line format
# Step 1: Query existing content first
sf data query --query "SELECT Demand_Plan_Next_Steps__c FROM UseCase__c WHERE Id = 'aAvXXXXXXXXXXXXXXX'" --json

# Step 2: Update with NEW entry prepended + ALL existing entries preserved
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "Demand_Plan_Next_Steps__c='Feb-25 - LP - Status: On track
Last: Call with customer completed.
Next: Follow up on technical review.
Risk: None

<PASTE_ALL_EXISTING_ENTRIES_HERE>'"

# Update Target Onboarding Date [AE]
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "Implementation_Start_Date__c=2026-02-01"

# Update Target Live Date [AE]
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "Full_Production_Date__c=2026-03-15"

# Update Use Case Health [SA] - Red, Yellow, or Green
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "Implementation_Status__c=Yellow"

# Update Implementation Notes [AE]
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "Implementation_Notes__c='Enablement needed: Y\nEnablement team engaged: Y\nImplementation Contact: John Smith (Customer PM)'"

# Update In Plan / Out of Plan [AE]
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "UseCaseInPlan__c=true"

# Update DSA [DSA] - requires User ID
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "DSA__c=005XXXXXXXXXXXX"

# Update Stage (valid values: U1, U2, U3, U4, U5, U6, Lost, Disqualified)
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "Stages__c=U3"

# Update Manager Notes [FLM] - OPTIONAL, managers only
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "ManagerNotes__c='High Potential Accounts\nUCO1: Strong exec sponsorship\nUCO2: Expanding to new BU'"

# --- COMBINED WEEKLY UPDATE (all fields at once) ---
# IMPORTANT: Query existing Demand_Plan_Next_Steps__c first, then include ALL previous entries
sf data update record --sobject UseCase__c --record-id aAvXXXXXXXXXXXXXXX \
  --values "Demand_Plan_Next_Steps__c='Feb-25 - LP - Status: On track
Last: POC progressing well.
Next: Expect completion by 1/20.
Risk: None

<PASTE_ALL_EXISTING_ENTRIES_HERE>' \
  Implementation_Status__c=Green \
  Implementation_Start_Date__c=2026-02-01 \
  Full_Production_Date__c=2026-03-15 \
  UseCaseInPlan__c=true"
```

### Finding User IDs for DSA Assignment

```bash
# Search for DSA by name
sf data query --query "SELECT Id, Name, Email FROM User WHERE Name LIKE '%Smith%' AND IsActive = true"

# Search for DSA by email
sf data query --query "SELECT Id, Name, Email FROM User WHERE Email = 'john.smith@databricks.com'"
```
